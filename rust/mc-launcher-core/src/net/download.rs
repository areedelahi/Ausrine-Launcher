

use std::{
    fs::{self, File},
    io,
    path::PathBuf,
};

use crate::{
    io::hash::sha1_file,
    progress::{ProgressEvent, ProgressReporter, SkipReason},
    LauncherError, Result,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Checksum {

    Sha1(String),

    Sha256(String),
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct DownloadTask {

    pub url: String,

    pub destination: PathBuf,

    pub checksum: Option<Checksum>,

    pub label: String,

    pub size: Option<u64>,

    pub lzma_compressed: bool,

    pub executable: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct DownloadPlan {

    pub tasks: Vec<DownloadTask>,
}

pub fn should_skip_existing(task: &DownloadTask) -> Result<bool> {
    if !task.destination.exists() {
        return Ok(false);
    }
    if let Some(Checksum::Sha1(expected)) = &task.checksum {
        let actual = sha1_file(&task.destination)?;
        if actual == *expected {
            return Ok(true);
        }
        // Delete the corrupted file
        let _ = fs::remove_file(&task.destination);
        return Ok(false);
    }
    Ok(true)
}

struct ProgressWrapper<R, F> {
    inner: R,
    on_read: F,
}

impl<R: std::io::Read, F: FnMut(usize)> std::io::Read for ProgressWrapper<R, F> {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        let n = self.inner.read(buf)?;
        if n > 0 {
            (self.on_read)(n);
        }
        Ok(n)
    }
}

enum WorkerMessage {
    Event(ProgressEvent),
    ChunkRead(u64),
    TaskSkipped(u64),
}

pub fn execute_plan_sequential(plan: &DownloadPlan, reporter: &mut dyn ProgressReporter) -> Result<()> {
    let client = super::http::client()?;
    let total_plan_bytes: u64 = plan.tasks.iter().map(|t| t.size.unwrap_or(0)).sum();
    let mut completed_plan_bytes: u64 = 0;

    for task in &plan.tasks {
        if should_skip_existing(task)? {
            completed_plan_bytes += task.size.unwrap_or(0);
            reporter.report(ProgressEvent::PlanProgress {
                completed_bytes: completed_plan_bytes,
                total_bytes: total_plan_bytes,
            });
            reporter.report(ProgressEvent::TaskSkipped {
                label: task.label.clone(),
                reason: if task.checksum.is_some() {
                    SkipReason::ChecksumMatched
                } else {
                    SkipReason::FileExistsWithoutChecksum
                },
            });
            continue;
        }

        reporter.report(ProgressEvent::TaskStarted {
            label: task.label.clone(),
            path: task.destination.clone(),
        });

        if let Some(parent) = task.destination.parent() {
            fs::create_dir_all(parent)?;
        }
        let response = client.get(&task.url).send()?.error_for_status()?;
        let total = response.content_length();
        let mut file = std::io::BufWriter::new(File::create(&task.destination)?);

        let mut received = 0;
        let mut wrapped = ProgressWrapper {
            inner: response,
            on_read: |n| {
                received += n as u64;
                completed_plan_bytes += n as u64;
                reporter.report(ProgressEvent::BytesReceived {
                    label: task.label.clone(),
                    received,
                    total,
                });
                reporter.report(ProgressEvent::PlanProgress {
                    completed_bytes: completed_plan_bytes,
                    total_bytes: total_plan_bytes,
                });
            }
        };

        if task.lzma_compressed {
            lzma_rs::lzma_decompress(&mut std::io::BufReader::new(wrapped), &mut file)
                .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        } else {
            std::io::copy(&mut wrapped, &mut file)?;
        }

        if task.executable {
            #[cfg(unix)]
            {
                let _ = std::process::Command::new("chmod").arg("+x").arg(&task.destination).status();
            }
        }

        if let Some(Checksum::Sha1(expected)) = &task.checksum {
            let actual = sha1_file(&task.destination)?;
            if actual != *expected {
                let _ = fs::remove_file(&task.destination);
                return Err(LauncherError::ChecksumMismatch {
                    path: task.destination.clone(),
                    expected: expected.clone(),
                    actual,
                });
            }
        }

        reporter.report(ProgressEvent::TaskFinished {
            label: task.label.clone(),
        });
    }
    Ok(())
}

pub fn execute_plan(plan: &DownloadPlan, reporter: &mut dyn ProgressReporter) -> Result<()> {
    if plan.tasks.len() <= 1 {
        return execute_plan_sequential(plan, reporter);
    }

    use std::sync::{mpsc, Arc, Mutex};
    use std::thread;

    let num_threads = std::cmp::min(8, plan.tasks.len());
    let (tx, rx) = mpsc::channel();

    let tasks: Vec<DownloadTask> = plan.tasks.clone();
    let task_queue = Arc::new(Mutex::new(tasks.into_iter()));
    let mut handles = Vec::new();

    for _ in 0..num_threads {
        let task_queue = Arc::clone(&task_queue);
        let tx = tx.clone();

        handles.push(thread::spawn(move || {
            let client = match super::http::client() {
                Ok(c) => c,
                Err(e) => {
                    let _ = tx.send(Err(e));
                    return;
                }
            };

            loop {
                let task_opt = {
                    let mut q = task_queue.lock().unwrap();
                    q.next()
                };
                let Some(task) = task_opt else { break; };

                match should_skip_existing(&task) {
                    Ok(true) => {
                        let _ = tx.send(Ok(WorkerMessage::TaskSkipped(task.size.unwrap_or(0))));
                        let reason = if task.checksum.is_some() {
                            SkipReason::ChecksumMatched
                        } else {
                            SkipReason::FileExistsWithoutChecksum
                        };
                        let _ = tx.send(Ok(WorkerMessage::Event(ProgressEvent::TaskSkipped {
                            label: task.label.clone(),
                            reason,
                        })));
                        continue;
                    }
                    Ok(false) => {}
                    Err(e) => {
                        let _ = tx.send(Err(e));
                        return;
                    }
                }

                let _ = tx.send(Ok(WorkerMessage::Event(ProgressEvent::TaskStarted {
                    label: task.label.clone(),
                    path: task.destination.clone(),
                })));

                if let Some(parent) = task.destination.parent() {
                    if let Err(e) = fs::create_dir_all(parent) {
                        let _ = tx.send(Err(e.into()));
                        return;
                    }
                }

                let response_res = client.get(&task.url).send().and_then(|r| r.error_for_status());
                let response = match response_res {
                    Ok(r) => r,
                    Err(e) => {
                        let _ = tx.send(Err(e.into()));
                        return;
                    }
                };

                let total = response.content_length();
                let mut file = match File::create(&task.destination) {
                    Ok(f) => std::io::BufWriter::new(f),
                    Err(e) => {
                        let _ = tx.send(Err(e.into()));
                        return;
                    }
                };

                let mut received = 0;
                let wrapped = ProgressWrapper {
                    inner: response,
                    on_read: |n| {
                        received += n as u64;
                        let _ = tx.send(Ok(WorkerMessage::ChunkRead(n as u64)));
                        let _ = tx.send(Ok(WorkerMessage::Event(ProgressEvent::BytesReceived {
                            label: task.label.clone(),
                            received,
                            total,
                        })));
                    }
                };

                if task.lzma_compressed {
                    if let Err(e) = lzma_rs::lzma_decompress(&mut std::io::BufReader::new(wrapped), &mut file) {
                        let _ = tx.send(Err(std::io::Error::new(std::io::ErrorKind::InvalidData, e).into()));
                        return;
                    }
                } else {
                    let mut wrapped = wrapped;
                    if let Err(e) = std::io::copy(&mut wrapped, &mut file) {
                        let _ = tx.send(Err(e.into()));
                        return;
                    }
                }

                if task.executable {
                    #[cfg(unix)]
                    {
                        let _ = std::process::Command::new("chmod").arg("+x").arg(&task.destination).status();
                    }
                }

                if let Some(Checksum::Sha1(expected)) = &task.checksum {
                    let actual = match sha1_file(&task.destination) {
                        Ok(a) => a,
                        Err(e) => {
                            let _ = tx.send(Err(e.into()));
                            return;
                        }
                    };
                    if actual != *expected {
                        let _ = fs::remove_file(&task.destination);
                        let _ = tx.send(Err(LauncherError::ChecksumMismatch {
                            path: task.destination.clone(),
                            expected: expected.clone(),
                            actual,
                        }.into()));
                        return;
                    }
                }

                let _ = tx.send(Ok(WorkerMessage::Event(ProgressEvent::TaskFinished {
                    label: task.label.clone(),
                })));
            }
        }));
    }

    drop(tx);

    let total_plan_bytes: u64 = plan.tasks.iter().map(|t| t.size.unwrap_or(0)).sum();
    let mut completed_plan_bytes: u64 = 0;

    for msg in rx {
        match msg {
            Ok(WorkerMessage::Event(event)) => reporter.report(event),
            Ok(WorkerMessage::ChunkRead(n)) => {
                completed_plan_bytes += n;
                reporter.report(ProgressEvent::PlanProgress {
                    completed_bytes: completed_plan_bytes,
                    total_bytes: total_plan_bytes,
                });
            }
            Ok(WorkerMessage::TaskSkipped(size)) => {
                completed_plan_bytes += size;
                reporter.report(ProgressEvent::PlanProgress {
                    completed_bytes: completed_plan_bytes,
                    total_bytes: total_plan_bytes,
                });
            }
            Err(e) => return Err(e),
        }
    }

    for handle in handles {
        let _ = handle.join();
    }

    Ok(())
}

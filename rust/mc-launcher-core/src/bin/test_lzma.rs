use lzma_rs::lzma_decompress;
use std::io::Cursor;

fn main() {
    let mut input = Cursor::new(vec![0; 100]);
    let mut output = Cursor::new(Vec::new());
    match lzma_decompress(&mut input, &mut output) {
        Ok(_) => println!("Works"),
        Err(e) => println!("Error: {:?}", e),
    }
}

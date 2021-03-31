use std::io::Stdout;

use crossterm::cursor::MoveToNextLine;
use crossterm::execute;
use crossterm::style::Print;
use crossterm::terminal::ScrollUp;



pub fn create_terminal_promt_text(current_user: &str, hostname: &str, current_folder: &str) -> String {
    format!("{}@{}:{}# ", current_user, hostname, current_folder)
}

pub fn print_terminal_promt_text(stdout: &mut Stdout, current_user: &str, hostname: &str, current_folder: &str) {  
    execute!(
        stdout,
        MoveToNextLine(0),
        ScrollUp(1),
        Print(create_terminal_promt_text(current_user, &hostname, &current_folder)),
    ).unwrap();

}
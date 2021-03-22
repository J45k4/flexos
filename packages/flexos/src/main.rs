use std::process::exit;

use crossterm::{cursor, event::{Event, KeyCode, KeyEvent, KeyModifiers, read}, execute, style::{self, Print}, terminal::{Clear, ClearType, disable_raw_mode, enable_raw_mode}};

fn main() {
    let mut stdout = std::io::stdout();

    enable_raw_mode().unwrap();

    execute!(
        stdout,
        Clear(ClearType::All),
        Print("root@tyopaikka# ")
    ).unwrap();

    let mut cmd_buffer = String::new();

    let cmd_history: Vec<String> = Vec::new();

    loop {
        match read().unwrap() {
            Event::Key(KeyEvent {
                code: KeyCode::Enter,
                modifiers: KeyModifiers::NONE
            }) => {
                execute!(
                    stdout,
                    cursor::MoveToNextLine(1),
                    Print("root@tyopaikka# "),
                ).unwrap();
            }
            Event::Key(KeyEvent { code: KeyCode::Char(c), modifiers: KeyModifiers::NONE }) => {
                execute!(
                    stdout,
                    Print(format!("{}", c))
                ).unwrap();
            }
            Event::Key(KeyEvent { code: KeyCode::Char('c'), modifiers : KeyModifiers::CONTROL}) => {
                disable_raw_mode().unwrap();
                println!();

                exit(0);
            }
            Event::Key(KeyEvent { code: KeyCode::Up, modifiers: KeyModifiers::NONE }) => {
                
            }
            Event::Key(KeyEvent { code: KeyCode::Down, modifiers: KeyModifiers::NONE }) => {

            }
            Event::Key(KeyEvent { code: KeyCode::Left, modifiers: KeyModifiers::NONE }) => {
                execute!(
                    stdout,
                    cursor::MoveLeft(1)
                ).unwrap();
            }
            Event::Key(KeyEvent { code: KeyCode::Right, modifiers: KeyModifiers::NONE }) => {
                execute!(
                    stdout,
                    cursor::MoveRight(1)
                ).unwrap();
            }
            // Event::Resize(width, height) => println!("New size {}x{}", width, height),
            _ => {}
        };
    }
}

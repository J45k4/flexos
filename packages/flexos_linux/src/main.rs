use std::{fmt::format, io::{stdin, stdout, Write}};
// use termion::event::Key;
// use termion::input::TermRead;
// use termion::raw::IntoRawMode;

use crossterm::{cursor, event::{Event, KeyCode, KeyEvent, KeyModifiers, read}, execute, style::{self, Print}, terminal::enable_raw_mode};
use flexconsole::Console;

fn main() {
    let mut stdout = std::io::stdout();

    enable_raw_mode().unwrap();

    execute!(
        stdout,
        Print("root@tyopaikka# ")
    ).unwrap();

    let mut console = Console::new();

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
                console.add_character(c);

                execute!(
                    stdout,
                    Print(format!("{}", c))
                ).unwrap();
            }
            // Event::Resize(width, height) => println!("New size {}x{}", width, height),
            _ => {}
        };
    }

    // let mut stdin = stdin();

    // // print!("\x1b[0;31mSO\x1b[0m");

    // let mut stdout = stdout().into_raw_mode().unwrap();

    // print!("\x1Bc");
    // println!("Starting flexos....");
    // print!("root@tyopaikka#");

    // stdout.flush().unwrap();

    // write!(
    //     stdout,
    //     "{}{}",
    //     termion::cursor::Goto(1, 1),
    //     termion::clear::All
    // )
    // .unwrap();

    // // let mut buff: [u8; 300] = [0; 300]; 

    // // stdin.read(&mut buff).unwrap();

    // // println!("buff {:?}", buff);

    // for c in stdin.keys() {
    //     match c.unwrap() {
    //         Key::PageUp => {
    //             println!("pageup");
    //         }
    //         _ => {
    //             println!("dunno");
    //         }
    //     }
    // }
}

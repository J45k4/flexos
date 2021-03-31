
use std::process::exit;

use command::execute_terminal_cmd;
use console_visuals::print_terminal_promt_text;
use crossterm::cursor;
use crossterm::cursor::MoveLeft;
use crossterm::event::Event;
use crossterm::event::KeyCode;
use crossterm::event::KeyEvent;
use crossterm::event::KeyModifiers;
use crossterm::event::read;
use crossterm::execute;
use crossterm::style::Print;
use crossterm::terminal::disable_raw_mode;
use crossterm::terminal::enable_raw_mode;
use gethostname::gethostname;
use terminal_state::TerminalState;


mod command;
mod terminal_state;
mod console_visuals;

// fn handle_event(&mut ) {

// }

fn main() {
    // let v = env::var("PATH").unwrap();

    // println!("v {:?}", v.split(":"));

    let mut stdout = std::io::stdout();

    enable_raw_mode().unwrap();

    // execute!(
    //     stdout,
    //     Clear(ClearType::All),
    //     cursor::MoveTo(0, 0),
    //     Print("root@tyopaikka# ")
    // ).unwrap();

    
    let hostname = gethostname();
    let hostname = hostname.to_string_lossy();

    let mut terminal_state = TerminalState::new("/");

    print_terminal_promt_text(
        &mut stdout, 
        &terminal_state.get_current_user_name(), 
        &hostname, 
        &terminal_state.get_current_folder_path());

    let mut line_buffer = String::new();

    let mut cmd_history: Vec<String> = Vec::new();

    let mut offset = 0;
     
    loop {
        let line_buffer = &mut line_buffer;
        
        match read().unwrap() {
            Event::Key(KeyEvent {
                code: KeyCode::Enter,
                modifiers: KeyModifiers::NONE
            }) => {
                cmd_history.push(line_buffer.to_owned());

                // print_terminal_promt_text(
                //     &mut stdout, 
                //     &terminal_state.get_current_user_name(), 
                //     &hostname, 
                //     &terminal_state.get_current_folder_path());

                execute_terminal_cmd(&mut stdout, &mut terminal_state, &line_buffer);

                line_buffer.clear();
                offset = 0;

                print_terminal_promt_text(
                    &mut stdout, 
                    &terminal_state.get_current_user_name(), 
                    &hostname, 
                    &terminal_state.get_current_folder_path());
            }
            Event::Key(KeyEvent { code: KeyCode::Char('c'), modifiers : KeyModifiers::CONTROL}) => {
                disable_raw_mode().unwrap();
                println!();

                exit(0);
            }
            Event::Key(KeyEvent { code: KeyCode::Backspace, modifiers: KeyModifiers::NONE }) => {
                if offset == 0 {
                    continue;
                }

                if offset == line_buffer.len() {
                    execute!(
                        stdout,
                        cursor::MoveLeft(1),
                        Print(" "),
                        cursor::MoveLeft(1)
                    ).unwrap();

                    line_buffer.replace_range((offset - 1).., "");

                    offset -= 1;

                    continue;
                }

                let new_offset = offset - 1;

                let rest = line_buffer[offset..].to_string();

                let rest_len = rest.len() as u16;

                line_buffer.replace_range(new_offset.., "");
                line_buffer.insert_str(new_offset, &rest);

                offset = new_offset;

                execute!(
                    stdout,
                    MoveLeft(1),
                    Print(rest),
                    Print(" "),
                    MoveLeft(rest_len + 1)
                ).unwrap();
            }
            Event::Key(KeyEvent { code: KeyCode::Up, modifiers: KeyModifiers::NONE }) => {
                
            }
            Event::Key(KeyEvent { code: KeyCode::Down, modifiers: KeyModifiers::NONE }) => {

            }
            Event::Key(KeyEvent { code: KeyCode::Left, modifiers: KeyModifiers::NONE }) => {
                if offset == 0 {
                    continue;
                }

                offset -= 1;

                execute!(
                    stdout,
                    cursor::MoveLeft(1)
                ).unwrap();
            }
            Event::Key(KeyEvent { code: KeyCode::Right, modifiers: KeyModifiers::NONE }) => {
                if offset == line_buffer.len() {
                    continue;
                }

                offset += 1;

                execute!(
                    stdout,
                    cursor::MoveRight(1)
                ).unwrap();
            }
            Event::Key(KeyEvent { code: KeyCode::Char(c), modifiers: KeyModifiers::NONE }) => {
                if offset == line_buffer.len() {
                    line_buffer.push(c);
                    offset += 1;

                    execute!(
                        stdout,
                        Print(format!("{}", c))
                    ).unwrap();

                    continue;
                }

                let rest = line_buffer[offset..].to_string();

                let rest_len = rest.len();

                line_buffer.replace_range(offset.., "");
                line_buffer.push(c);
                line_buffer.insert_str(offset + 1, &rest);

                offset += 1;

                execute!(
                    stdout,
                    Print(c),
                    Print(rest),
                    cursor::MoveLeft(rest_len as u16)
                ).unwrap();

                // line_buffer = format!("{}{}", line_buffer[..offset], c);
            }
            // Event::Resize(width, height) => println!("New size {}x{}", width, height),
            _ => {}
        };
    }
}

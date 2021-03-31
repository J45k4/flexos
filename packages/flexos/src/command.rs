
use std::fs::metadata;
use std::fs::read_dir;
use std::io::ErrorKind;
use std::io::Stdout;
use std::io::Write;
use std::path::Path;

use crossterm::cursor::MoveToNextLine;
use crossterm::execute;
use crossterm::queue;
use crossterm::style::Print;
use crossterm::terminal::ScrollUp;

use crate::terminal_state::TerminalState;

fn does_contain_folder(path: &str, folder_name: &str) {

}

fn check_and_change_to(
    stdout: &mut Stdout,
    terminal_state: &mut TerminalState,
    path: &Path
) {
    let path_as_str = path.to_string_lossy();

    match metadata(path) {
        Ok(m) => {
            if m.file_type().is_file() == true {
                execute!(stdout, 
                    MoveToNextLine(0), 
                    ScrollUp(1), 
                    Print(format!("{} is a file", path_as_str)));

                return
            }

            terminal_state.set_current_folder(&path_as_str);
        }
        Err(e) => match e.kind() {
            ErrorKind::NotFound => {
                execute!(stdout, MoveToNextLine(0), ScrollUp(1), Print("Folder not found"));

                return;
            }
            // ErrorKind::PermissionDenied => {}
            // ErrorKind::ConnectionRefused => {}
            // ErrorKind::ConnectionReset => {}
            // ErrorKind::ConnectionAborted => {}
            // ErrorKind::NotConnected => {}
            // ErrorKind::AddrInUse => {}
            // ErrorKind::AddrNotAvailable => {}
            // ErrorKind::BrokenPipe => {}
            // ErrorKind::AlreadyExists => {}
            // ErrorKind::WouldBlock => {}
            // ErrorKind::InvalidInput => {}
            // ErrorKind::InvalidData => {}
            // ErrorKind::TimedOut => {}
            // ErrorKind::WriteZero => {}
            // ErrorKind::Interrupted => {}
            // ErrorKind::Other => {}
            // ErrorKind::UnexpectedEof => {}
            _ => {
                unimplemented!()
            }
        }
    };
}


pub fn execute_terminal_cmd<'a>(
    stdout: &mut Stdout,
    terminal_state: &mut TerminalState,
    // filesystem: &'a mut impl Filesystem<'a>,
    cmd: &str
) {
    let mut cmd_parts = cmd.split(" ");

    let app = match cmd_parts.next() {
        Some(a) => a,
        None => {
            unimplemented!();
        }
    };

    if app == "ls" {
        queue!(stdout,                             
            MoveToNextLine(0), 
            ScrollUp(1)
        ).unwrap();

        let current_folder_path = terminal_state.get_current_folder_path();

        let mut d = read_dir(current_folder_path.as_str()).unwrap();

        let mut line_counter = 0;

        while let Some(Ok(dir)) = d.next() {
            let name = dir.file_name();
            let filename = name.to_string_lossy();

            queue!(
                stdout,
                Print(format!("{} ", filename))
            );

            line_counter += 1;

            if line_counter > 10 {
                queue!(stdout,                             
                    MoveToNextLine(0), 
                    ScrollUp(1)
                ).unwrap();

                line_counter = 0;
            }
        }

        // let current_folder = terminal_state.get_current_folder();

        stdout.flush();

        return;
    }

    if app == "cd" {
        let path = match cmd_parts.next() {
            Some(r) => r,
            None => {
                return;
            }
        };

        if path.chars().nth(0).unwrap() == '/' {
            
            check_and_change_to(stdout, terminal_state, Path::new(path));
            return;
        }

        let whole_path = Path::new(terminal_state.get_current_folder_path().as_str())
            .join(path);

        check_and_change_to(stdout, terminal_state, &whole_path);

        

        // if path == "/" {
        //     println!("se on juuri polku");

        //     return
        // }

        // println!("path {}", path);
        
        // // let current_folder = { 
        // //     terminal_state.get_current_folder()
        // // };

        // let mut splitted = cmd.split(" ");

        // splitted.next();

        // let folder_path = splitted.next().unwrap();

        // terminal.set_current_folder(folder_path);

        return;
    }

    if app == "f" {

        return;
    }
}

// #[test]
// fn test_execute_ls_command_without_path() {
//     execute_terminal_cmd("ls")
// }

#[test]
fn test_cd_to_root_directory() {
    let terminal_state = TerminalState::new();

    execute_terminal_cmd(terminal_state, "cd /"); 
}

#[test]
fn test_cd_to_parent_directory() {
    let terminal_state = TerminalState::new();

    execute_terminal_cmd(terminal_state,"cd ../");
}

#[test]
fn test_cd_to_parent_directory_subdirectory() {
    let terminal_state = TerminalState::new();

    execute_terminal_cmd(terminal_state,"cd ../something");
}
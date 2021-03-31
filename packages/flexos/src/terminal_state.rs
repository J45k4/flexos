use std::borrow::Cow;

pub struct TerminalState {
    current_folder_path: String,
    current_user_name: String 
}

impl TerminalState {
    pub fn new(current_folder_path: &str) -> TerminalState {
        TerminalState{
            current_folder_path: current_folder_path.to_string(),
            current_user_name: "root".to_string()
        }
    }

    pub fn set_current_user_name(&mut self, user_name: &str) {
        self.current_user_name = user_name.to_string();
    }

    pub fn get_current_user_name(&self) -> Cow<String> {
        Cow::Borrowed(&self.current_user_name)
    }

    pub fn get_current_folder_path(&self) -> Cow<String> {
        Cow::Borrowed(&self.current_folder_path)
    }

    pub fn set_current_folder(&mut self, folder_path: &str) {
        self.current_folder_path = folder_path.to_string();
    }
}
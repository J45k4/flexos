
pub struct Console {
    write_buffer: String,
    history: Vec<String>
}

impl Console {
    pub fn new() -> Console {
        Console{
            write_buffer: "".to_string(),
            history: Vec::new()
        }
    }

    pub fn add_character(&mut self, c: char) {
        self.write_buffer.push(c);
    }

    pub fn remove_character(&mut self) {
        self.write_buffer.pop();
    }

    pub
     
    pub fn go_up_in_history() {

    }

    pub fn go_down_in_history() {

    }

    pub fn execute() {

    }
}
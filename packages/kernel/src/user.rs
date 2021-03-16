use std::u16;

struct User {
    id: u16
}

impl User {
    fn new(id: u16) -> User {
        User {
            id: id
        }
    }
}
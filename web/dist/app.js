class FlexosDesktop {
    root;
    constructor(root){
        this.root = root;
        this.root;
    }
}
window.onload = ()=>{
    console.log("WIndow loaded");
    const root = document.querySelector("#root");
    if (!root) {
        return;
    }
    new FlexosDesktop(root);
};
console.log("hello too");

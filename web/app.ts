import { FlexosDesktop } from "./flexos_desktop.ts"

window.onload = () => {
    console.log("WIndow loaded");

    const root = document.querySelector("#root")

    if (!root) {
        return
    }

    const flexosDesktop = new FlexosDesktop(root as HTMLElement)
}

console.log("hello too")
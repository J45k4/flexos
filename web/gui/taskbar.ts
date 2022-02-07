// import { View } from "./view.ts"

// export class Taskbar {
//     public constructor() {
//         const view = new View()


//     }
// }

type UiView = {
    type: "view"
    children: UiNode[]
}

type UiText = {
    type: "text"
    text: string
}

type UiButton = {
    type: "button"
    text: string
    onClick: () => void
}

type UiWindow = {
    type: "window"
}

type UiNode = UiView | UiText | UiButton | UiWindow

export const enum FlexDirection {
    row,
    column
}

const View = (props?: {
    flexDirection?: FlexDirection,
}) => {
    return (...children: any): UiNode => {
        return {
            type: "view",
            children: []
        }
    }
}

const Text = (props?: {
    text: string
}) => {

}

const Button = (props?: {
    text: string
}) => {


}

export const Taskbar2 = () => {
    return View()(
        View({
            flexDirection: FlexDirection.row,
        })(
            Text({
                text: "Test text"
            }),
            Button({
                text: "Test button",
                onClick: () => {
                    console.log("Clicked")
                }
            }),
            View()
        )
    )
}

const Window = () => {

}

const GuiApp = () => {

}
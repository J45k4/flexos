
export const enum FlexDirection {
    row,
    column
}

export class View {
    private flexDirection: FlexDirection
    private flexGrow: number

    public constructor(args?: {
        flexDirection?: FlexDirection,
        flexGrow?: number
    }) {
        this.flexDirection = FlexDirection.column
        this.flexGrow = 0

        if (args) {
            if (args.flexDirection) {
                this.flexDirection = args.flexDirection
            }

            if (args.flexGrow) {
                this.flexGrow = args.flexGrow   
            }
        }
    }
}
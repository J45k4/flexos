# Flexos

What is Flexos ?

It is a operating system which can be user on top of following platforms:

- Browser (WebAssembly)
- Linux
- Windows
- MacOS
- Android
- iOS ?
- Bare metal Maybe 🤷‍♂️

Flexos is not run only on single machine but it can use resources from multiple machines. It uses if possible it uses LAN to communicate with other machines but can be exposed to internet similar how ssh is exposed to internet.

## Resources

### Disks

Access to any disks that are available in the system. It can be local disk, network disk or cloud disk. Using any of these options should be transparent to the user.

### GPU

Access to GPU for rendering and computing. GPU resources can be shared between multiple machines through LAN or internet. It would be possible to use GPU resources from cloud.

### CPU

Access to CPU resources from other machines. This would be useful for example when running some heavy computations.

### Screens

Display content on any screens that are connected to any instances. However it probably only mkaes to use screens physically close to you.

## Security

It is possible to enable end to end encryption,

### Permissions

Flexos has finegrained permission system which allows access to varios things. Applications need to ask permission to access various resources.

## VR

Flexos has native support for virtual reality. Desktop environment supports placing applications in 3D space and they should stay still.

## AI

Flexos has support for various APIs which can b eused for LLM api calls. Flexos has default assistant AI which can be used for various tasks. Applications can independly expose their own interfaces for the usage of AI. In order for AI assistant to be usefull it needs to be able to do various things. Assistant implementation should not be locked to only single implmentation but is possible to use various implementations. Also cloud resources can be used for AI computations. AI assistants should be just normal applications which means they need to ask permission to access services just like other applications.

## Applications

### Calculator

Just normal calculator.

### Currency convertter

### Notepad

### Audio Control

### Stopwatch

### Timer

### Snipping Tool

### TODO List

### Calendar

### Email

### Hex editor

### Translator

### Chat

### Video call

### Spreadsheet

### PDF tool

### Diagram drawing tool


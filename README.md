# Simple TCP endpoint in P4

### Created by: Lilla Novák, Bálint Balázs, Máté Barbér

To run this example, clone the repository in your Mininet BMv2 enviroment, then open the folder called `implementation` in terminal and run the following command:

```
make
```

After the mininet started correctly, run this command:

```
xterm h1
```

When a new terminal windows appears in your screen, run this command:

```
nc 10.0.3.3 75
```

After that, everything you write in your console before you hit the `Enter` button will be sended to the server, then it will be processed and sended back to you.

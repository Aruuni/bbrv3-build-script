Compiles the BBRv3 kernel on the current machine, copying your config file over. Hopefully this woun't be needed in the near future. 
Install the necessary prerequisites:
```
sudo apt-get install git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison
```
Usage: 
```
sudo install.sh -m localhost 
```

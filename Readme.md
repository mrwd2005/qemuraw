

usage
=====

sudo wget qemuraw.sh
sudo chmod +x ./qemuraw.sh
sudo ./qemuraw.sh -i qemuraw

extras
=====

1, enter **mac linuxpe** to correct mac adress

mount vda4
vi grub.cfg

2,enter **dataextend winpe** to rebuild data partiption


start diskgen
bak the 32mb start
del and rebuild a new "raid" part as big as possible,this will destory start part,this is normal
rebuild the start part in the former free space behind of data part,make it boot active,restore the bak files


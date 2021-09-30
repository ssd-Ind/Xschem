sudo apt update
sudo apt install git --assume-yes
sudo apt-get update -y
sudo apt install libx11-dev libxrender1 libxrender-dev libxcb1 tcl8.6 \
                 libx11-xcb-dev libcairo2 libcairo2-dev tcl8.6-dev tk8.6 \
                 tk8.6-dev flex bison libxpm4 libxpm-dev gawk mawk automake \
                 libtool build-essential gperf libxml2 libxml2-dev libxml-libxml-perl \
                 libgd-perl libxaw7-dev libreadline6-dev vim-gtk3 --assume-yes
cd
git clone https://github.com/StefanSchippers/xschem.git
cd xschem
./configure
make -j4
sudo make install
xschem &
cd
cd .xschem
mkdir xschem_library
cd xschem_library
git clone https://github.com/StefanSchippers/xschem_sky130.git xschem_sky130
xschem &
cd
mkdir projects
cd projects
mkdir foundry
cd foundry
git clone https://github.com/google/skywater-pdk
cd skywater-pdk
git submodule init libraries/sky130_fd_io/latest
git submodule init libraries/sky130_fd_pr/latest
git submodule init libraries/sky130_fd_sc_hd/latest
git submodule init libraries/sky130_fd_sc_hvl/latest
git submodule init libraries/sky130_fd_sc_hdll/latest
git submodule init libraries/sky130_fd_sc_hs/latest
git submodule init libraries/sky130_fd_sc_ms/latest
git submodule init libraries/sky130_fd_sc_ls/latest
git submodule init libraries/sky130_fd_sc_lp/latest
git submodule update
cd libraries
cp -a sky130_fd_pr sky130_fd_pr_ngspice
cd sky130_fd_pr_ngspice/latest
patch -p2 < ~/.xschem/xschem_library/xschem_sky130/sky130_fd_pr.patch
cd
git clone https://git.code.sf.net/p/ngspice/ngspice ngspice
cd ngspice
git checkout pre-master
./autogen.sh
mkdir release
cd release
../configure --with-x --enable-xspice --disable-debug --enable-cider --with-readline=yes --enable-openmp
make -j4
sudo make install
cd
# cd .xschem/simulations
# vi .spiceinit
# set ngbehavior=hs
# Press i
# :wq
# cd
cd .xschem/xschem_library/xschem_sky130
xschem &

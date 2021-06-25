#!/usr/bin/env bash

## GPL,Written By MoeClub.org and linux-live.org,moded by minlearn (https://gitee.com/minlearn/minstack/) for minstackos remastering and installing (both local install and cloud dd) purposes and for onedrive mirror/image hosting.
## meant to work/tested under linux and osx with bash > 4
## usage: diweb.sh -i minstackos|qemuraw

# =================================================================
# globals
# =================================================================

# mirror settings
export custMIRROR='https://github.com/minlearn/qemuraw/raw/master'
export custIMGMIRROR='https://github.com/minlearn/qemuraw/raw/master'

# BUILD/HOST/TARGET tripe
export tmpBUILD='0' #0:linux,1:unix,osx
export tmpHOST='0'  #0:cloud host;1:bearmetal
export tmpTARGET='' #debianbase(none),minstackos,winsrvcore2019,deepin20,dsm61715284,osx10146

# tripe addons,which seldom needed be adjusted
export tmpHOSTMODEL=''
export tmpTARGETMODE='0'  #0:REMASTERING+CLOUDDDINSTALL MODE? 1:REMASTERING+BUILD MODE? defaultly it sholudbe 0
export tmpTARGETDDURL=''
export tmpTARGETINSTANTWITHOUTVNC='0'

# customables
export custWORD=''
export custIPADDR=''
export custIPMASK=''
export custIPGATE=''

# dir settings
downdir='_build/tmpdown'
remasteringdir='_build/tmpremastering'
targetdir='_build/tmptarget'

export PATH=.:./tools:../tools:/usr/sbin:/usr/bin:/sbin:/bin:/
topdir=$(dirname $(readlink -f $0))
cd $topdir

[[ "$EUID" -ne '0' ]] && echo "Error:This script must be run as root!" && exit 1
[[ ! "$(bash --version | head -n 1 | grep -o '[1-9]'| head -n 1)" -ge '4' ]] && echo "Error:bash must be at least 4!" && exit 1
[[ "$(uname)" == "Darwin" ]] && tmpBUILD='1' && read -s -n1 -p "osx detected"

while [[ $# -ge 1 ]]; do
  case $1 in
    -h|--host)
      tmpHOST="$2"
      [[ "$tmpHOST" == '1' ]] && read -s -n1 -p "baremetal host args given,will use the only support mbp hostmodel and set TARGETMODE as 1" && tmpHOSTMODEL='mbp' && tmpTARGETMODE='1' && echo -en "\n" && [[ -z "$tmpHOSTMODEL" ]] && echo "hostmodel were empty" && exit 1
      [[ "$tmpHOST" == '0' ]] && tmpTARGETMODE='1'
      shift
      shift
      ;;
    -i|--install)
      shift
      tmpTARGET="$1"
      case $tmpTARGET in
        debianbase) tmpTARGETMODE='1' ;;
        minstackos|qemuraw) [[ "$tmpHOST" != '2' && "$tmpTARGET" == 'minstackos' ]] && tmpTARGETMODEL=1 || tmpTARGETMODEL='0';[[ "$tmpTARGETMODE" != '1' ]] && read -s -n1 -p "instmode detected" && tmpTARGETDDURL=$custIMGMIRROR/imgs/xa || read -s -n1 -p "genmode detected,a bridge interface on host with dhcp/dns support needed in advance,or the scripts will fail,press any key to continue or ctlc to exit ... " ;;
        deepin20|win10ltsc|winsrv2019|dsm61715284|osx10146) tmpTARGETMODE='0';tmpTARGETDDURL=${custIMGMIRROR2//minstack/images}/$tmpTARGET".gz" ;;
        *) echo "$tmpTARGET" |grep -q '^http://\|^ftp://\|^https://';[[ $? -ne '0' ]] && echo "targetname not known" && exit 1 || read -s -n1 -p "raw urls detected" && tmpTARGETDDURL=$tmpTARGET ;;
      esac
      shift
      ;;
    -i|--instantwithoutvnc)
      shift
      tmpTARGETINSTANTWITHOUTVNC="$1"
      shift
      ;;
    -p|--password)
      shift
      custWORD="$1"
      shift
      ;;
    --ip-addr)
      shift
      custIPADDR="$1"
      shift
      ;;
    --ip-mask)
      shift
      custIPMASK="$1"
      shift
      ;;
    --ip-gate)
      shift
      custIPGATE="$1"
      shift
      ;;
    *)
      if [[ "$1" != 'error' ]]; then echo -ne "\nInvaild option: '$1'\n\n"; fi
      echo -ne " Usage(args are self explained):\n\tbash $(basename $0)\t-i/--install\n\t\t\t\t-i/--instantwithoutvnc\n\t\t\t\t-p/--password\n\t\t\t\t--ip-addr/--ip-gate/--ip-mask\n\t\t\t\t\n"
      exit 1;
      ;;
    esac
  done

clear

# =================================================================
# Below are function libs
# =================================================================

function CheckDependence(){
  FullDependence='0';
  lostdeplist="";
  for BIN_DEP in `[[ "$tmpBUILDFORM" -ne '0' ]] && echo "$1" |sed 's/,/\n/g' || echo "$1" |sed 's/,/\'$'\n''/g'`
    do
      if [[ -n "$BIN_DEP" ]]; then
        Founded='1';
        for BIN_PATH in `[[ "$tmpBUILDFORM" -ne '0' ]] && echo "$PATH" |sed 's/:/\n/g' || echo "$PATH" |sed 's/:/\'$'\n''/g'`
          do
            ls $BIN_PATH/$BIN_DEP >/dev/null 2>&1;
            if [ $? == '0' ]; then
              Founded='0';
              break;
            fi
          done
        echo -en "[ \033[32m $BIN_DEP";
        if [ "$Founded" == '0' ]; then
          echo -en ",ok \033[0m] ";
        else
          FullDependence='1';
          echo -en ",\033[31m not ok \033[0m] ";
          lostdeplist+="$BIN_DEP"
        fi
      fi
  done
  if [ "$FullDependence" == '1' ]; then
    echo -ne "\n \033[31m Error! \033[0m Please use '\033[33m apt-get \033[0m' or '\033[33m yum \033[0m' or '\033[33m brew \033[0m' install it.\n"
    [[ $lostdeplist =~ "ar" ]] && echo "ar: in debian:binutils"
    [[ $lostdeplist =~ "xzcat" ]] && echo "xzcat: debian:xz-utils brew:xz"
    [[ $lostdeplist =~ "md5sum" || $lostdeplist =~ "sha1sum" || $lostdeplist =~ "sha256sum" ]] && echo "brew:coreutils"
    [[ $lostdeplist =~ "losetup" ]] && echo "losetup: debian:util-linux"
    [[ $lostdeplist =~ "parted" ]] && echo "parted: debian:parted"
    [[ $lostdeplist =~ "mkfs.vfat" ]] && echo "mkfs.vfat: debian:dosfstools"
    [[ $lostdeplist =~ "squashfs" ]] && echo "mksquashfs: debian:squashfs-tools"
    [[ $lostdeplist =~ "systemd-nspawn" ]] && echo "systemd-nspawn: debian:systemd-container"
    exit 1;
  fi
}

function SelectFastestValidMirrorFrom3(){

  [ $# -ge 1 ] || exit 1

  declare -A MirrorTocheck
  MirrorTocheck=(["Debian0"]="" ["Debian1"]="" ["Debian2"]="")
  
  echo "$1" |sed 's/\ //g' |grep -q '^http://\|^https://\|^ftp://' && MirrorTocheck[Debian0]=$(echo "$1" |sed 's/\ //g');
  echo "$2" |sed 's/\ //g' |grep -q '^http://\|^https://\|^ftp://' && MirrorTocheck[Debian1]=$(echo "$2" |sed 's/\ //g');
  echo "$3" |sed 's/\ //g' |grep -q '^http://\|^https://\|^ftp://' && MirrorTocheck[Debian2]=$(echo "$3" |sed 's/\ //g');

  SpeedLog0=''
  SpeedLog1=''
  SpeedLog2=''

  for mirror in `[[ "$tmpBUILDFORM" -ne '0' ]] && echo "${!MirrorTocheck[@]}" |sed 's/\ /\n/g' |sort -n |grep "^Debian" || echo "${!MirrorTocheck[@]}" |sed 's/\ /\'$'\n''/g' |sort -n |grep "^Debian"`
    do
      CurMirror="${MirrorTocheck[$mirror]}"

      [ -n "$CurMirror" ] || continue

      # CheckPass1='0';
      # DistsList="$(wget --no-check-certificate -qO- "$CurMirror/dists/" |grep -o 'href=.*/"' |cut -d'"' -f2 |sed '/-\|old\|Debian\|experimental\|stable\|test\|sid\|devel/d' |grep '^[^/]' |sed -n '1h;1!H;$g;s/\n//g;s/\//\;/g;$p')";
      # for DIST in `echo "$DistsList" |sed 's/;/\n/g'`
        # do
          # [[ "$DIST" == "buster" ]] && CheckPass1='1' && break;
        # done
      # [[ "$CheckPass1" == '0' ]] && {
        # echo -ne '\nbuster not find in $CurMirror/dists/, Please check it! \n\n'
        # bash $0 error;
        # exit 1;
      # }

      # CheckPass2=0
      # ImageFile="SUB_MIRROR/releases/linux"
      # [ -n "$ImageFile" ] || exit 1
      # URL=`echo "$ImageFile" |sed "s#SUB_MIRROR#${CurMirror}#g"`
      # wget --no-check-certificate --spider --timeout=3 -o /dev/null "$URL"
      # [ $? -eq 0 ] && CheckPass2=1 && echo "$CurMirror" && break
    # done

      CurrentMirrorSpeed=$(curl --connect-timeout 10 -m 10 -Lo /dev/null -skLw "%{speed_download}" $CurMirror/debian/dists/buster/1m) && CurrentMirrorSpeed=${CurrentMirrorSpeed/.*}
      [ "$mirror" == "Debian0" ] && SpeedLog0="$CurrentMirrorSpeed"
      [ "$mirror" == "Debian1" ] && SpeedLog1="$CurrentMirrorSpeed"
      [ "$mirror" == "Debian2" ] && SpeedLog2="$CurrentMirrorSpeed"
    done
    [[ "$SpeedLog0" != "0.000" && "$SpeedLog0" -gt "$SpeedLog1" && "$SpeedLog0" -gt "$SpeedLog2" ]] && echo "${MirrorTocheck[Debian0]}"
    [[ "$SpeedLog1" != "0.000" && "$SpeedLog1" -gt "$SpeedLog0" && "$SpeedLog1" -gt "$SpeedLog2" ]] && echo "${MirrorTocheck[Debian1]}"
    [[ "$SpeedLog2" != "0.000" && "$SpeedLog2" -gt "$SpeedLog0" && "$SpeedLog2" -gt "$SpeedLog1" ]] && echo "${MirrorTocheck[Debian2]}"

    # [[ $CheckPass2 == 0 ]] && {
      # echo -ne "\033[31m Error! \033[0m the file linux not find in $CurMirror/releases/! \n";
      # bash $0 error;
      # exit 1;
    # }

}

function CheckTarget(){

  if [[ -n "$1" ]]; then
    echo "$1" |grep -q '^http://\|^ftp://\|^https://';
    [[ $? -ne '0' ]] && echo 'No valid URL in the DD argument,Only support http://, ftp:// and https:// !' && exit 1;

    IMGHEADERCHECK="$(curl -IsL "$1")";
    IMGTYPECHECK="$(echo "$IMGHEADERCHECK"|grep -E -o '200|302'|head -n 1)" || IMGTYPECHECK='0';

    #directurl style,just 1
    [[ "$IMGTYPECHECK" == '200' ]] && \
    {
      # IMGSIZE
      UNZIP='1' && sleep 3s && echo -en "[ \033[32m x-gzip \033[0m ]";
    }

    # refurl style,(no more imgheadcheck and 1 more imgtypecheck pass needed)
    [[ "$IMGTYPECHECK" == '302' ]] && \
    IMGTYPECHECKPASS_REF="$(echo "$IMGHEADERCHECK"|grep -E -o 'raw|qcow2|gzip|x-gzip'|head -n 1)" && {
      # IMGSIZE
      [[ "$IMGTYPECHECKPASS_REF" == 'raw' ]] && UNZIP='0' && sleep 3s && echo -e "[ \033[32m raw \033[0m ]";
      [[ "$IMGTYPECHECKPASS_REF" == 'qcow2' ]] && UNZIP='0' && sleep 3s && echo -e "[ \033[32m raw \033[0m ]";
      [[ "$IMGTYPECHECKPASS_REF" == 'gzip' ]] && UNZIP='1' && sleep 3s && echo -e "[ \033[32m gzip \033[0m ]";
      [[ "$IMGTYPECHECKPASS_REF" == 'x-gzip' ]] && UNZIP='1' && sleep 3s && echo -e "[ \033[32m x-gzip \033[0m ]";
      [[ "$IMGTYPECHECKPASS_REF" == 'gunzip' ]] && UNZIP='2' && sleep 3s && echo -e "[ \033[32m gunzip \033[0m ]";
    }

    [[ "$UNZIP" == '' ]] && echo 'didnt got a unzip mode, you may input a incorrect url,or the bad network traffic caused it,exit ... !' && exit 1;
    #[[ "$IMGSIZE" -le '10' ]] && echo 'img too small,is there sth wrong? exit ... !' && exit 1;
    [[ "$IMGTYPECHECK" == '0' ]] && echo 'not a raw,tar,gunzip or 301/302 ref file, exit ... !' && exit 1;

  else
    echo 'Please input vaild image URL! ';
    exit 1;
  fi

}


function getpkgs(){

  declare -A OPTPKGS
  OPTPKGS=(
    ["libc1"]="dists/buster/main/debian-installer/binary-amd64/deb/libc6_2.28-10_amd64.deb"

    ["common1"]="dists/buster/main/debian-installer/binary-amd64/deb/libgnutls30_3.6.7-4-deb10u6_amd64.deb"
    ["common2"]="dists/buster/main/debian-installer/binary-amd64/deb/libp11-kit0_0.23.15-2-deb10u1_amd64.deb"
    ["common3"]="dists/buster/main/debian-installer/binary-amd64/deb/libtasn1-6_4.13-3_amd64.deb"
    ["common4"]="dists/buster/main/debian-installer/binary-amd64/deb/libnettle6_3.4.1-1_amd64.deb"
    ["common5"]="dists/buster/main/debian-installer/binary-amd64/deb/libhogweed4_3.4.1-1_amd64.deb"
    ["common6"]="dists/buster/main/debian-installer/binary-amd64/deb/libgmp10_6.1.2-dfsg-4_amd64.deb"

    ["busybox1"]="dists/buster/main/debian-installer/binary-amd64/deb/busybox_1.30.1-4_amd64.deb"

    ["wgetssl1"]="dists/buster/main/debian-installer/binary-amd64/deb/libidn2-0_2.0.5-1-deb10u1_amd64.deb"
    ["wgetssl2"]="dists/buster/main/debian-installer/binary-amd64/deb/libpsl5_0.20.2-2_amd64.deb"
    ["wgetssl3"]="dists/buster/main/debian-installer/binary-amd64/deb/libpcre2-8-0_10.32-5_amd64.deb"
    ["wgetssl4"]="dists/buster/main/debian-installer/binary-amd64/deb/libuuid1_2.33.1-0.1_amd64.deb"
    ["wgetssl5"]="dists/buster/main/debian-installer/binary-amd64/deb/zlib1g_1.2.11.dfsg-1_amd64.deb"
    ["wgetssl6"]="dists/buster/main/debian-installer/binary-amd64/deb/libssl1.1_1.1.1d-0-deb10u5_amd64.deb"
    ["wgetssl7"]="dists/buster/main/debian-installer/binary-amd64/deb/openssl_1.1.1d-0-deb10u5_amd64.deb"
    ["wgetssl8"]="dists/buster/main/debian-installer/binary-amd64/deb/wget_1.20.1-1.1_amd64.deb"
    ["wgetssl9"]="dists/buster/main/debian-installer/binary-amd64/deb/libunistring2_0.9.10-1_amd64.deb"
    ["wgetssl10"]="dists/buster/main/debian-installer/binary-amd64/deb/libffi6_3.2.1-9_amd64.deb"

    ["ddprogress1"]="dists/buster/main/debian-installer/binary-amd64/deb/libncursesw5_5.9-20140913-1-deb8u3_amd64.deb"
    ["ddprogress2"]="dists/buster/main/debian-installer/binary-amd64/deb/libtinfo5_5.9-20140913-1-deb8u3_amd64.deb"
    ["ddprogress3"]="dists/buster/main/debian-installer/binary-amd64/deb/debianutils_4.4-b1_amd64.deb"
    ["ddprogress4"]="dists/buster/main/debian-installer/binary-amd64/deb/sensible-utils_0.0.9-deb8u1_all.deb"
    ["ddprogress5"]="dists/buster/main/debian-installer/binary-amd64/deb/pv_1.5.7-2_amd64.deb"
    ["ddprogress6"]="dists/buster/main/debian-installer/binary-amd64/deb/dialog_1.2-20140911-1_amd64.deb"

    ["webfs1"]="dists/buster/main/debian-installer/binary-amd64/deb/mime-support_3.62_all.deb"
    ["webfs2"]="dists/buster/main/debian-installer/binary-amd64/deb/webfs_1.21-ds1-12_amd64.deb"

    ["xorg1"]="pool/ldeb/xorg.ldeb"
    #["xorg2"]="pool/ldeb/chromium.ldeb"

    ["faasd1"]="pool/ldeb/containerd.ldeb"
    ["faasd2"]="pool/ldeb/buildkit.ldeb"
    ["faasd3"]="pool/ldeb/faasd.ldeb"

    ["vscodeonline1"]="pool/ldeb/vscodeonline.ldeb"

  )

  echo -en "Downloading optional/necessary deb pkg files ...... ";

  for pkg in `[[ "$tmpBUILDFORM" -ne '0' ]] && echo "$1" |sed 's/,/\n/g' || echo "$1" |sed 's/,/\'$'\n''/g'`
    do
    
      [[ -n "${OPTPKGS[$pkg"1"]}" ]] && {

        for subpkg in `[[ "$tmpBUILDFORM" -ne '0' ]] && echo "${!OPTPKGS[@]}" |sed 's/\ /\n/g' |sort -n |grep "^$pkg" || echo "${!OPTPKGS[@]}" |sed 's/\ /\'$'\n''/g' |sort -n |grep "^$pkg"`
          do
            cursubpkgfile="${OPTPKGS[$subpkg]}"
            [ -n "$cursubpkgfile" ] || continue

            cursubpkgfilepath=${cursubpkgfile%/*}
            mkdir -p $downdir/debian/$cursubpkgfilepath
            cursubpkgfilename=${cursubpkgfile##*/}
            cursubpkgfilename2=$(echo $cursubpkgfilename|sed "s/\(+\|~\)/-/g")

            echo -en "\033[s \033[K [ \033[32m ${cursubpkgfilename2:0:10} \033[0m ] \033[u"
            [[ ! -f $downdir/debian/$cursubpkgfilepath/$cursubpkgfilename2 ]] && wget --no-check-certificate -qO $downdir/debian/$cursubpkgfilepath/$cursubpkgfilename2 $MIRROR/mirror/debian/$cursubpkgfile && [[ $? -ne '0' ]] && echo "download failed" && exit 1; \

          done
            # [[ ! -f  /tmp/boot/${OPTPKGS["bin"$pkg]}2 ]] && echo 'Error! $1 SUPPORT ERROR.' && exit 1;
      }

    done

}

ipNum()
{
  local IFS='.';
  read ip1 ip2 ip3 ip4 <<<"$1";
  echo $((ip1*(1<<24)+ip2*(1<<16)+ip3*(1<<8)+ip4));
}

SelectMax(){
  ii=0;
  for IPITEM in `route -n |awk -v OUT=$1 '{print $OUT}' |grep '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'`
    do
      NumTMP="$(ipNum $IPITEM)";
      eval "arrayNum[$ii]='$NumTMP,$IPITEM'";
      ii=$[$ii+1];
    done
  echo ${arrayNum[@]} |sed 's/\s/\n/g' |sort -n -k 1 -t ',' |tail -n1 |cut -d',' -f2;
}

alyzgrubentry(){

  [[ "$GRUBVER" == '0' ]] && {

    mkdir -p $remasteringdir/grub

    READGRUB=''$remasteringdir'/grub/grub.read'
    cat $GRUBDIR/$GRUBFILE |sed -n '1h;1!H;$g;s/\n/%%%%%%%/g;$p' |grep -om 1 'menuentry\ [^{]*{[^}]*}%%%%%%%' |sed 's/%%%%%%%/\n/g' >$READGRUB
    LoadNum="$(cat $READGRUB |grep -c 'menuentry ')"
    if [[ "$LoadNum" -eq '1' ]]; then
      cat $READGRUB |sed '/^$/d' >$remasteringdir/grub/grub.new;
    elif [[ "$LoadNum" -gt '1' ]]; then
      CFG0="$(awk '/menuentry /{print NR}' $READGRUB|head -n 1)";
      CFG2="$(awk '/menuentry /{print NR}' $READGRUB|head -n 2 |tail -n 1)";
      CFG1="";
      for tmpCFG in `awk '/}/{print NR}' $READGRUB`
        do
          [ "$tmpCFG" -gt "$CFG0" -a "$tmpCFG" -lt "$CFG2" ] && CFG1="$tmpCFG";
        done
      [[ -z "$CFG1" ]] && {
        echo "Error! read $GRUBFILE. ";
        exit 1;
      }

      sed -n "$CFG0,$CFG1"p $READGRUB >$remasteringdir/grub/grub.new;
      [[ -f $remasteringdir/grub/grub.new ]] && [[ "$(grep -c '{' $remasteringdir/grub/grub.new)" -eq "$(grep -c '}' $remasteringdir/grub/grub.new)" ]] || {
        echo -ne "\033[31m Error! \033[0m Not configure $GRUBFILE. \n";
        exit 1;
      }
    fi
    [ ! -f $remasteringdir/grub/grub.new ] && echo "Error! $GRUBFILE. " && exit 1;
    sed -i "/menuentry.*/c\menuentry\ \'DI PE \[debian\ buster\ amd64\]\'\ --class debian\ --class\ gnu-linux\ --class\ gnu\ --class\ os\ \{" $remasteringdir/grub/grub.new
    sed -i "/echo.*Loading/d" $remasteringdir/grub/grub.new;
    INSERTGRUB="$(awk '/menuentry /{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
  }

  [[ "$GRUBVER" == '1' ]] && {
    CFG0="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)";
    CFG1="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 2 |tail -n 1)";
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 == $CFG0 ] && sed -n "$CFG0,$"p $GRUBDIR/$GRUBFILE >$remasteringdir/grub/grub.new;
    [[ -n $CFG0 ]] && [ -z $CFG1 -o $CFG1 != $CFG0 ] && sed -n "$CFG0,$[$CFG1-1]"p $GRUBDIR/$GRUBFILE >$remasteringdir/grub/grub.new;
    [[ ! -f $remasteringdir/grub/grub.new ]] && echo "Error! configure append $GRUBFILE. " && exit 1;
    sed -i "/title.*/c\title\ \'DebianNetboot \[buster\ amd64\]\'" $remasteringdir/grub/grub.new;
    sed -i '/^#/d' $remasteringdir/grub/grub.new;
    INSERTGRUB="$(awk '/title[\ ]|title[\t]/{print NR}' $GRUBDIR/$GRUBFILE|head -n 1)"
  }

}

# =================================================================
# Below are main routes
# =================================================================

echo -e "\n\n\n\n\n\n\n\n\n\n \033[36m # Checking Prerequisites: \033[0m \n"

echo -en "Checking deps ......:"
if [[ "$tmpTARGET" == 'debianbase' ]] && [[ "$tmpTARGETMODE" == '1' ]]; then
  CheckDependence wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,xzcat,zcat,md5sum,sha1sum,sha256sum;
elif [[ "$tmpTARGET" == 'minstackos' ]] && [[ "$tmpTARGETMODE" == '1' ]] && [[ "$tmpBUILD" == '0' ]] ; then
  CheckDependence wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,xzcat,zcat,losetup,parted,mkfs.vfat,mksquashfs,chroot,systemd-nspawn;
elif [[ "$tmpTARGET" == 'minstackos' ]] && [[ "$tmpTARGETMODE" == '1' ]] && [[ "$tmpBUILD" == '1' ]] ; then
  CheckDependence wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,xzcat,zcat,diskutil;
else
  CheckDependence wget,ar,awk,grep,sed,cut,cat,cpio,curl,gzip,find,dirname,basename,xzcat,zcat;
fi
echo -en "\n"

MIRROR=$(SelectFastestValidMirrorFrom3 $custMIRROR $custMIRROR1 $custMIRROR2)
[ -n "$MIRROR" ] && echo -en "Selecting The Fastest Mirror ......:" && echo -en "[ \033[32m ${MIRROR} \033[0m ]\n" || exit 1

UNZIP=''
IMGSIZE=''

echo -en "\rChecking TARGET ......."


if [[ "$tmpTARGETMODE" == '0' && "$tmpTARGET" != 'minstackos' ]]; then
  CheckTarget $tmpTARGETDDURL;
else
  echo -e "[ \033[32m skipping!! \033[0m ]"
fi

sleep 2s

echo -e "\n \033[36m # Parepare Res: \033[0m\n"


[[ -d $downdir ]] && rm -rf $downdir;
mkdir -p $downdir $downdir/debian/dists/buster/main/binary-amd64

if [[ "$tmpTARGET" == 'minstackos' ]] && [[ "$tmpTARGETMODE" == '1' ]]; then
  getpkgs xorg; ##,faasd,vscodeonline; ##Dialog,debconf-utils,openssh-server(let this be front aside xorg,etc..)
elif [[ "$tmpTARGETMODE" == '0' ]]; then
  getpkgs libc,common,wgetssl;
else
  getpkgs ;
fi
sleep 2s

echo -en "\nsave the netcfg ......"

setNet='0'
interface=''

[[ "$tmpBUILD" == '0' && "$tmpTARGETMODE" == '0' && "$tmpTARGET" != 'debianbase' ]] && {

  [ -n "$custIPADDR" ] && [ -n "$custIPMASK" ] && [ -n "$custIPGATE" ] && setNet='1';
  [[ -n "$custWORD" ]] && myPASSWORD="$(openssl passwd -1 "$custWORD")";
  [[ -z "$myPASSWORD" ]] && myPASSWORD='$1$4BJZaD0A$y1QykUnJ6mXprENfwpseH0';

  if [[ -n "$interface" ]]; then
    IFETH="$interface"
  else
    IFETH="auto"
  fi

  [[ "$setNet" == '1' ]] && {
    IPv4="$custIPADDR";
    MASK="$custIPMASK";
    GATE="$custIPGATE";
  } || {
    DEFAULTNET="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.*' |head -n1 |sed 's/proto.*\|onlink.*//g' |awk '{print $NF}')";
    [[ -n "$DEFAULTNET" ]] && IPSUB="$(ip addr |grep ''${DEFAULTNET}'' |grep 'global' |grep 'brd' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}/[0-9]\{1,2\}')";
    IPv4="$(echo -n "$IPSUB" |cut -d'/' -f1)";
    NETSUB="$(echo -n "$IPSUB" |grep -o '/[0-9]\{1,2\}')";
    GATE="$(ip route show |grep -o 'default via [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}')";
    [[ -n "$NETSUB" ]] && MASK="$(echo -n '128.0.0.0/1,192.0.0.0/2,224.0.0.0/3,240.0.0.0/4,248.0.0.0/5,252.0.0.0/6,254.0.0.0/7,255.0.0.0/8,255.128.0.0/9,255.192.0.0/10,255.224.0.0/11,255.240.0.0/12,255.248.0.0/13,255.252.0.0/14,255.254.0.0/15,255.255.0.0/16,255.255.128.0/17,255.255.192.0/18,255.255.224.0/19,255.255.240.0/20,255.255.248.0/21,255.255.252.0/22,255.255.254.0/23,255.255.255.0/24,255.255.255.128/25,255.255.255.192/26,255.255.255.224/27,255.255.255.240/28,255.255.255.248/29,255.255.255.252/30,255.255.255.254/31,255.255.255.255/32' |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}'${NETSUB}'' |cut -d'/' -f1)";
  }

  [[ -n "$GATE" ]] && [[ -n "$MASK" ]] && [[ -n "$IPv4" ]] || {
    echo "Not found \`ip command\`, It will use \`route command\`."


    [[ -z $IPv4 ]] && IPv4="$(ifconfig |grep 'Bcast' |head -n1 |grep -o '[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}' |head -n1)";
    [[ -z $GATE ]] && GATE="$(SelectMax 2)";
    [[ -z $MASK ]] && MASK="$(SelectMax 3)";

    [[ -n "$GATE" ]] && [[ -n "$MASK" ]] && [[ -n "$IPv4" ]] || {
      echo "Error! Not configure network. ";
      exit 1;
    }
  }

  [[ "$setNet" != '1' ]] && [[ -f '/etc/network/interfaces' ]] && {
    [[ -z "$(sed -n '/iface.*inet static/p' /etc/network/interfaces)" ]] && AutoNet='1' || AutoNet='0';
    [[ -d /etc/network/interfaces.d ]] && {
      ICFGN="$(find /etc/network/interfaces.d -name '*.cfg' |wc -l)" || ICFGN='0';
      [[ "$ICFGN" -ne '0' ]] && {
        for NetCFG in `ls -1 /etc/network/interfaces.d/*.cfg`
          do 
            [[ -z "$(cat $NetCFG | sed -n '/iface.*inet static/p')" ]] && AutoNet='1' || AutoNet='0';
            [[ "$AutoNet" -eq '0' ]] && break;
          done
      }
    }
  }

  [[ "$setNet" != '1' ]] && [[ -d '/etc/sysconfig/network-scripts' ]] && {
    ICFGN="$(find /etc/sysconfig/network-scripts -name 'ifcfg-*' |grep -v 'lo'|wc -l)" || ICFGN='0';
    [[ "$ICFGN" -ne '0' ]] && {
      for NetCFG in `ls -1 /etc/sysconfig/network-scripts/ifcfg-* |grep -v 'lo$' |grep -v ':[0-9]\{1,\}'`
        do 
          [[ -n "$(cat $NetCFG | sed -n '/BOOTPROTO.*[dD][hH][cC][pP]/p')" ]] && AutoNet='1' || {
            AutoNet='0' && . $NetCFG;
            [[ -n $NETMASK ]] && MASK="$NETMASK";
            [[ -n $GATEWAY ]] && GATE="$GATEWAY";
          }
          [[ "$AutoNet" -eq '0' ]] && break;
        done
    }
  }

} || echo -en "[ \033[32m skipping!! \033[0m ]\n"



echo -e "\n \033[36m # Remastering all up... \033[0m \n"



[[ -d $remasteringdir ]] && rm -rf $remasteringdir;


sleep 2s && echo -en "\runpacking grub files ..."


mkdir -p $targetdir
export tmpMNT=_build/tmptarget/mnt

[[ "$tmpTARGETMODE" == '1' && "$tmpTARGET" == 'minstackos' ]] && {
  prepareimg
}




LoaderMode='0'
setInterfaceName='0'
setIPv6='0'

[[ "$tmpBUILD" == '0' && "$tmpTARGETMODE" == '0' && "$tmpTARGET" != 'debianbase' ]] && {

  if [[ "$LoaderMode" == "0" ]]; then
    [[ -f '/boot/grub/grub.cfg' ]] && GRUBVER='0' && GRUBDIR='/boot/grub' && GRUBFILE='grub.cfg';
    [[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub2/grub.cfg' ]] && GRUBVER='0' && GRUBDIR='/boot/grub2' && GRUBFILE='grub.cfg';
    [[ -z "$GRUBDIR" ]] && [[ -f '/boot/grub/grub.conf' ]] && GRUBVER='1' && GRUBDIR='/boot/grub' && GRUBFILE='grub.conf';
    [ -z "$GRUBDIR" -o -z "$GRUBFILE" ] && echo -ne "Error! \nNot Found grub.\n" && exit 1;
  else
    tmpTARGETINSTANTWITHOUTVNC='0'
  fi

  if [[ "$LoaderMode" == "0" ]]; then
    [[ ! -f $GRUBDIR/$GRUBFILE ]] && echo "Error! Not Found $GRUBFILE. " && exit 1;

    [[ ! -f $GRUBDIR/$GRUBFILE.old ]] && [[ -f $GRUBDIR/$GRUBFILE.bak ]] && mv -f $GRUBDIR/$GRUBFILE.bak $GRUBDIR/$GRUBFILE.old;
    mv -f $GRUBDIR/$GRUBFILE $GRUBDIR/$GRUBFILE.bak;
    [[ -f $GRUBDIR/$GRUBFILE.old ]] && cat $GRUBDIR/$GRUBFILE.old >$GRUBDIR/$GRUBFILE || cat $GRUBDIR/$GRUBFILE.bak >$GRUBDIR/$GRUBFILE;
  else
    GRUBVER='2'
  fi

  alyzgrubentry

  if [[ "$LoaderMode" == "0" ]]; then
    [[ -n "$(grep 'linux.*/\|kernel.*/' $remasteringdir/grub/grub.new |awk '{print $2}' |tail -n 1 |grep '^/boot/')" ]] && Type='InBoot' || Type='NoBoot';

    LinuxKernel="$(grep 'linux.*/\|kernel.*/' $remasteringdir/grub/grub.new |awk '{print $1}' |head -n 1)";
    [[ -z "$LinuxKernel" ]] && echo "Error! read grub config! " && exit 1;
    LinuxIMG="$(grep 'initrd.*/' $remasteringdir/grub/grub.new |awk '{print $1}' |tail -n 1)";
    [ -z "$LinuxIMG" ] && sed -i "/$LinuxKernel.*\//a\\\tinitrd\ \/" $remasteringdir/grub/grub.new && LinuxIMG='initrd';

    if [[ "$setInterfaceName" == "1" ]]; then
      Add_OPTION="net.ifnames=0 biosdevname=0";
    else
      Add_OPTION="";
    fi

    if [[ "$setIPv6" == "1" ]]; then
      Add_OPTION="$Add_OPTION ipv6.disable=1";
    fi

    BOOT_OPTION="auto=true $Add_OPTION hostname=debian domain= -- quiet"

    [[ "$Type" == 'InBoot' ]] && {
      sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/boot\/vmlinuz $BOOT_OPTION" $remasteringdir/grub/grub.new;
      sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/boot\/initrfs.img" $remasteringdir/grub/grub.new;
    }

    [[ "$Type" == 'NoBoot' ]] && {
      sed -i "/$LinuxKernel.*\//c\\\t$LinuxKernel\\t\/vmlinuz $BOOT_OPTION" $remasteringdir/grub/grub.new;
      sed -i "/$LinuxIMG.*\//c\\\t$LinuxIMG\\t\/initrfs.img" $remasteringdir/grub/grub.new;
    }

    sed -i '$a\\n' $remasteringdir/grub/grub.new;
  fi

  sleep 2s && echo -en "[ \033[32m $remasteringdir/grub/grub.new \033[0m ]"

}



sleep 2s && echo -en "\nprocessing grub ......"

# pve need cgroup_enable=memory cgroup_memory=1 swapaccount=1
[[ -d $tmpMNT ]] && [[ "$tmpTARGETMODE" == '1' ]] && [[ "$tmpTARGET" == "minstackos" ]] && sed -i "s/minstack/minstack(perch)/g" $remasteringdir/grub/grub.cfg && sed -i "s|boot/vmlinuz|boot/vmlinuz cgroup_enable=memory cgroup_memory=1 swapaccount=1 live slax.flags=perch # intel_iommu=on|g" $remasteringdir/grub/grub.cfg && mkdir -p "$tmpMNT"/boot/grub && cp -a --no-preserve=all $remasteringdir/grub/* "$tmpMNT"/boot/grub


[[ "$tmpTARGETINSTANTWITHOUTVNC" == '0' ]] && {

  GRUBPATCH='0';

  if [[ "$LoaderMode" == "0" && "$tmpBUILD" != "1" && "$tmpTARGETMODE" == '0' ]]; then
    [ -f '/etc/network/interfaces' -o -d '/etc/sysconfig/network-scripts' ] || {
      echo "Error, Not found interfaces config.";
      exit 1;
    }

    sed -i ''${INSERTGRUB}'i\\n' $GRUBDIR/$GRUBFILE;
    sed -i ''${INSERTGRUB}'r '$remasteringdir'/grub/grub.new' $GRUBDIR/$GRUBFILE;

    sed -i 's/timeout_style=hidden/timeout_style=menu/g' $GRUBDIR/$GRUBFILE;
    sed -i 's/timeout=[0-9]*/timeout=30/g' $GRUBDIR/$GRUBFILE;

    [[ -f  $GRUBDIR/grubenv ]] && sed -i 's/saved_entry/#saved_entry/g' $GRUBDIR/grubenv;
  fi


  sleep 2s && echo -en "\nunpacking initrfs ......"

  mkdir -p $remasteringdir/initramfs/usr/bin $remasteringdir/01-core;
  cd $remasteringdir/initramfs;

  # IncFirmware='0'
  #mkdir -p $downdir/dists/buster/installer-live-amd64/current/images;
  #[[ ! -f $downdir/dists/buster/installer-live-amd64/current/images/vmlinuz ]] && wget --no-check-certificate -qO "$downdir/dists/buster/installer-live-amd64/current/images/vmlinuz" "${MIRROR}/dists/buster/installer-live-amd64/current/images/vmlinuz" && [[ $? -ne '0' ]] && echo -ne " \033[31m Error! \033[0m Download 'vmlinuz' for \033[33m debian \033[0m failed! \n" && exit 1 || echo -ne "[ \033[32m vmlinuz \033[0m ]"
  #[[ ! -f $downdir/dists/buster/installer-live-amd64/current/images/initrfs.img ]] && wget --no-check-certificate -qO "$downdir/dists/buster/installer-live-amd64/current/images/initrfs.img" "${MIRROR}/dists/buster/installer-live-amd64/current/images/initrfs.img" && [[ $? -ne '0' ]] && echo -ne " \033[31m Error! \033[0m Download 'initrfs.img' for \033[33m debian \033[0m failed! \n" && exit 1 || echo -en "[ \033[32m initrfs.img \033[0m ]"

  #MirrorHost="$(echo "$MIRROR" |awk -F'://|/' '{print $2}')";
  #MirrorFolder="$(echo "$MIRROR" |awk -F''${MirrorHost}'' '{print $2}')";

  #if [[ "$IncFirmware" == '1' ]]; then
  #  wget --no-check-certificate -qO '/boot/firmware.cpio.gz' "http://cdimage.debian.org/cdimage/unofficial/non-free/firmware/buster/current/firmware.cpio.gz"
  #  [[ $? -ne '0' ]] && echo -ne " \033[31m Error! \033[0m Download 'firmware' for \033[33m debian \033[0m failed! \n" && exit 1
  #fi

  # vKernel_udeb=$(wget --no-check-certificate -qO- "http://busterMirror/dists/$DIST/main/installer-amd64/current/images/udeb.list" |grep '^acpi-modules' |head -n1 |grep -o '[0-9]\{1,2\}.[0-9]\{1,2\}.[0-9]\{1,2\}-[0-9]\{1,2\}' |head -n1)
  # [[ -z "vKernel_udeb" ]] && vKernel_udeb="3.16.0-6"


  # --no-absolute-filenames??
  wget -qO-  $MIRROR/mirror/debian/initrfs.img | xz --decompress -c | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1
  # cp -af $remasteringdir/initramfs/initrd $remasteringdir/01-core

  [[ -f '/boot/firmware.cpio.gz' ]] && {
    gzip -d < /boot/firmware.cpio.gz | cpio --extract --verbose --make-directories --no-absolute-filenames >>/dev/null 2>&1
  }


  sleep 2s &&   echo -en "\nprocessing initrfs ...."

  find $topdir/$downdir/debian/dists/buster -type f \( -name *.deb -o -name *.ldeb \) | while read line; do line2=${line##*/};echo -en "\033[s \033[K [ \033[32m ${line2:0:40} \033[0m ] \033[u";[[ $(ar -t ${line} | grep  -E -o data.tar.gz) == 'data.tar.gz' ]] && ar -p ${line} data.tar.gz |zcat|tar -xf - -C $topdir/$remasteringdir/initramfs || ar -p ${line} data.tar.xz |xzcat|tar -xf - -C $topdir/$remasteringdir/initramfs; done


  if [[ "$tmpTARGETMODE" == '0' ]]; then


    sleep 2s && echo -en "\nmake a separated preseed file for cdi images......."

    # wget -qO- '$DDURL' |gzip -dc |dd of=$(list-devices disk |head -n1)|(pv -s \$IMGSIZE -n) 2&>1|dialog --gauge "progress" 10 70 0
    [[ "$UNZIP" == '0' ]] && PIPECMDSTR='wget -qO- '$tmpTARGETDDURL' |dd of=$(list-devices disk |head -n1)';
    [[ "$UNZIP" == '1' && "$tmpTARGET" != 'minstackos' ]] && PIPECMDSTR='wget -qO- '$tmpTARGETDDURL' |tar zOx |dd of=$(list-devices disk |head -n1)';
    [[ "$tmpTARGET" == 'minstackos' || "$tmpTARGET" == 'qemuraw' ]] && PIPECMDSTR='(for i in a b c d e f g h i;do wget -qO- '$tmpTARGETDDURL'$i; done)|tar zOx |dd of=$(list-devices disk |head -n1)';
    [[ "$UNZIP" == '2' ]] && PIPECMDSTR='wget -qO- '$tmpTARGETDDURL' |gzip -dc |dd of=$(list-devices disk |head -n1)';

    cat >$topdir/$remasteringdir/initramfs/preseed.cfg<<EOF
d-i preseed/early_command string anna-install

d-i debian-installer/locale string en_US
d-i debian-installer/framebuffer boolean false
d-i console-setup/layoutcode string us

d-i keyboard-configuration/xkb-keymap string us

d-i hw-detect/load_firmware boolean true

d-i netcfg/choose_interface select $IFETH
d-i netcfg/disable_autoconfig boolean true
d-i netcfg/dhcp_failed note
d-i netcfg/dhcp_options select Configure network manually
# d-i netcfg/get_custIPADDRess string $custIPADDR
d-i netcfg/get_custIPADDRess string $IPv4
d-i netcfg/get_netmask string $MASK
d-i netcfg/get_gateway string $GATE
d-i netcfg/get_nameservers string 8.8.8.8
d-i netcfg/no_default_route boolean true
d-i netcfg/confirm_static boolean true

d-i mirror/country string manual
#d-i mirror/http/hostname string $IPv4
d-i mirror/http/hostname string $MIRROR
d-i mirror/http/directory string /mirror/debian
d-i mirror/http/proxy string
d-i apt-setup/services-select multiselect
d-i debian-installer/allow_unauthenticated boolean true

d-i passwd/root-login boolean ture
d-i passwd/make-user boolean false
d-i passwd/root-password-crypted password $myPASSWORD
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

d-i clock-setup/utc boolean true
d-i time/zone string US/Eastern
d-i clock-setup/ntp boolean true

# kill -9 (ps |grep debian-util-shell | awk '{print 1}')
# debconf-set partman-auto/disk "\$(list-devices disk |head -n1)"
d-i partman/early_command string $PIPECMDSTR; \
sbin/reboot
EOF

    [[ "$LoaderMode" != "0" ]] && AutoNet='1'

    [[ "$setNet" == '0' ]] && [[ "$AutoNet" == '1' ]] && {
      sed -i '/netcfg\/disable_autoconfig/d' $topdir/$remasteringdir/initramfs/preseed.cfg
      sed -i '/netcfg\/dhcp_options/d' $topdir/$remasteringdir/initramfs/preseed.cfg
      sed -i '/netcfg\/get_.*/d' $topdir/$remasteringdir/initramfs/preseed.cfg
      sed -i '/netcfg\/confirm_static/d' $topdir/$remasteringdir/initramfs/preseed.cfg
    }

    #[[ "$GRUBPATCH" == '1' ]] && {
    #  sed -i 's/^d-i\ grub-installer\/bootdev\ string\ default//g' $topdir/$remasteringdir/initramfs/preseed.cfg
    #}
    #[[ "$GRUBPATCH" == '0' ]] && {
    #  sed -i 's/debconf-set\ grub-installer\/bootdev.*\"\;//g' $topdir/$remasteringdir/initramfs/preseed.cfg
    #}

    sed -i '/user-setup\/allow-password-weak/d' $topdir/$remasteringdir/initramfs/preseed.cfg
    sed -i '/user-setup\/encrypt-home/d' $topdir/$remasteringdir/initramfs/preseed.cfg
    #sed -i '/pkgsel\/update-policy/d' $topdir/$remasteringdir/initramfs/preseed.cfg
    #sed -i 's/umount\ \/media.*true\;\ //g' $topdir/$remasteringdir/initramfs/preseed.cfg

    sleep 2s &&   echo -en "\nmake a safe wget wrapper to inc --no-check-certificate"

    mv $topdir/$remasteringdir/initramfs/usr/bin/wget $topdir/$remasteringdir/initramfs/usr/bin/wget2
    cat >$topdir/$remasteringdir/initramfs/usr/bin/wget<<EOF
#!/bin/sh
rdlkf() { [ -L "\$1" ] && (local lk="\$(readlink "\$1")"; local d="\$(dirname "$1")"; cd "\$d"; local l="\$(rdlkf "\$lk")"; ([[ "\$l" = /* ]] && echo "\$l" || echo "\$d/\$l")) || echo "\$1"; }
DIR="\$(dirname "\$(rdlkf "\$0")")"
exec /usr/bin/env wget2 --no-check-certificate "\$@"
EOF
    chmod +x $topdir/$remasteringdir/initramfs/usr/bin/wget
  fi


  echo -en "\ncopying vmlinuz to the target/mnt ......"
  [[ -d /boot ]] && [[ "$tmpBUILD" != "1" ]] && [[ "$tmpTARGETMODE" == "0" ]] && wget -qO-  $MIRROR/mirror/debian/vmlinuz > /boot/vmlinuz
  [[ -d $topdir/$targetdir/mnt/boot ]] && [[ "$tmpTARGETMODE" == "1" ]] && [[ "$tmpTARGET" == "minstackos" ]] && wget -qO-  $MIRROR/mirror/debian/vmlinuz > $topdir/$targetdir/mnt/boot/vmlinuz

  #echo "current pwd is:"$CWD
  [[ "$tmpTARGETMODE" == '0' ]] && sleep 2s && echo -en "\npackaging initrfs to the target/mnt....." && [[ "$tmpBUILD" == '0' ]] && find . | cpio -H newc --create --quiet | gzip -9 > /boot/initrfs.img #|| find . | cpio -H rpax --create --quiet | gzip -9 > /Volumes/TMPVOL/initrfs.img
  [[ "$tmpTARGETMODE" == '1' ]] && sleep 2s && echo -en "\npackaging finished,and all done! auto reboot after 9999s...(if needed, you can press ctrl c to interrupt to bak the downdir under tmp/, then manually reboot to continue)" && sleep 9999s

  rm -rf $remasteringdir/initramfs;

}

[[ "$tmpTARGETINSTANTWITHOUTVNC" == '1' ]] && {
  sed -i '$i\\n' $GRUBDIR/$GRUBFILE
  sed -i '$r $remasteringdir/grub/grub.new' $GRUBDIR/$GRUBFILE
  echo -e "\n \033[33m \033[04m It will reboot! \nPlease connect VNC! \nSelect \033[0m \033[32m DI PE [debian buster amd64] \033[33m \033[4m to install system. \033[04m\n\n \033[31m \033[04m There is some information for you.\nDO NOT CLOSE THE WINDOW! \033[0m\n"
  echo -e "\033[35m IPv4\t\tNETMASK\t\tGATEWAY \033[0m"
  echo -e "\033[36m \033[04m $IPv4 \033[0m \t \033[36m \033[04m $MASK \033[0m \t \033[36m \033[04m $GATE \033[0m \n\n"

  read -n 1 -p "Press Enter to reboot..." INP
  [[ "$INP" != '' ]] && echo -ne '\b \n\n';
}

chown root:root $GRUBDIR/$GRUBFILE
chmod 444 $GRUBDIR/$GRUBFILE


if [[ "$LoaderMode" == "0" ]]; then
  echo -en "\npackaging finished,and all done! auto rebooting after 10s" && sleep 10s && clear && reboot >/dev/null 2>&1
else
  rm -rf "$HOME/loader"
  mkdir -p "$HOME/loader"
  cp -rf "/boot/initrfs.img" "$HOME/loader/initrfs.img"
  cp -rf "/boot/vmlinuz" "$HOME/loader/vmlinuz"
  [[ -f "/boot/initrfs.img" ]] && rm -rf "/boot/initrfs.img"
  [[ -f "/boot/vmlinuz" ]] && rm -rf "/boot/vmlinuz"
  echo && ls -AR1 "$HOME/loader"
fi

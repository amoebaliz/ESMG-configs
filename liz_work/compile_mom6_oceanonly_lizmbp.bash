#!/bin/bash

MOM6_installdir=/Users/elizabethdrenkard/TOOLS/ESMG-configs
MOM6_rundir=/Users/elizabethdrenkard/TOOLS/ESMG-configs/liz_work

export PATH=/opt/local/bin:${PATH}
export PATH=/opt/local/include:${PATH}
#export PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:/opt/local/lib/openmpi-gcc8/pkgconfig
export PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:/opt/local/lib/mpich-mp/pkgconfig
#---------------------------------------------------------------
# use new modules that point to /t1

#module load netcdf/4.3.0-gcc4.4.7
#module load openmpi/1.8.5_gcc4.4.7

cd $MOM6_rundir

# Create blank env file
rm -Rf $MOM6_rundir/build
echo > build/gnu/env

mkdir -p build/mkmf
# COPY OVER binary files
cp -r $MOM6_installdir/src/mkmf/bin $MOM6_rundir/build/mkmf/bin
cp -r $MOM6_installdir/src/mkmf/templates $MOM6_rundir/build/mkmf/templates
cp $MOM6_installdir/src/mkmf/templates/macOS-gnu8-mpich3.mk   $MOM6_rundir/build/mkmf/templates

compile_fms=1
compile_mom=1
if [ $compile_fms == 1 ] ; then
   # Compile FMS shared code.
   mkdir -p $MOM6_rundir/build/gnu/shared/repro/
   (cd $MOM6_rundir/build/gnu/shared/repro/; rm -f path_names; \
   $MOM6_rundir/build/mkmf/bin/list_paths -l $MOM6_installdir/src/FMS; \
   $MOM6_rundir/build/mkmf/bin/mkmf -t $MOM6_rundir/build/mkmf/templates/macOS-gnu8-mpich3.mk -p libfms.a -c "-Duse_libMPI -Duse_netCDF -DSPMD -D__APPLE__" path_names)

   # EJD: REMOVE ALL REFERENCES TO affinity.c & affinity.o from path_names & Makefile
   #      FOR MACOSX COMPILE
   sed -i '' '/affinity.c/d' $MOM6_rundir/build/gnu/shared/repro/path_names
   sed -i '' '/affinity.c/d' $MOM6_rundir/build/gnu/shared/repro/Makefile
   sed -i '' 's/affinity.o//g' $MOM6_rundir/build/gnu/shared/repro/Makefile 
  
   # BUILD FMS library
   (cd $MOM6_rundir/build/gnu/shared/repro/; source ../../env; make NETCDF=3 REPRO=1 FC=mpif90 CC=mpicc libfms.a -j)

fi

cd $MOM6_rundir

if [ $compile_mom == 1 ] ; then
    #rm -Rf $MOM6_rundir/build/gnu/ocean_only/repro/
    mkdir -p $MOM6_rundir/build/gnu/ocean_only/repro/
    (cd $MOM6_rundir/build/gnu/ocean_only/repro/; rm -f path_names; \
    $MOM6_rundir/build/mkmf/bin/list_paths -l ./ $MOM6_installdir/src/MOM6/{config_src/dynamic_symmetric,config_src/solo_driver,src/{*,*/*}}/ ; \
    $MOM6_rundir/build/mkmf/bin/mkmf -t $MOM6_rundir/build/mkmf/templates/macOS-gnu8-mpich3.mk -o '-I../../shared/repro' -p 'MOM6 -L../../shared/repro -lfms' -c '-Duse_libMPI -Duse_netCDF -DSPMD' path_names )
    (cd $MOM6_rundir/build/gnu/ocean_only/repro/; . ../../env; make NETCDF=3 REPRO=1 FC=mpif90 LD=mpif90 MOM6 -j)

fi


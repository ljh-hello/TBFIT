module mpi_basics
   implicit none
#ifdef MPI
   include 'mpif.h'
#endif
   logical :: flag_use_mpi
   integer :: npar
   integer :: kpar
   integer :: nproc_per_band
   integer :: mpi_comm_earth
   integer :: myid
   integer :: nprocs

   type mpicomm 
        integer :: mpi_comm
        integer :: myid
        integer :: nprocs
        integer :: npar
        integer :: kpar
      
        ! following values are generated by mpi_divide routine
        integer :: dims(2) ! grid dimension, (1) : nprow, (2) : npcol ! gener
        integer :: mycoord(2) ! default 2-dimensional cartesian topology, only meaningful if COMM_EARTH
   endtype

endmodule mpi_basics

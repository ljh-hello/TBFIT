#include "alias.inc"
subroutine read_kpoint(fname, PKPTS, PGEOM, PINPT)
  use parameters, only : kpoints, poscar, pid_kpoint, incar
  use mpi_setup
  use print_io
  implicit none
  integer*4, parameter :: max_kline=100
  integer*4     i_continue, nitems,ndiv_temp
  integer*4     i,linecount, i_dummy
  integer*4     idiv_mode
  integer*4     mpierr
  real*8        kline_dummy(3,max_kline)
  real*8, allocatable :: kpts_cart(:,:), kpts_reci(:,:)
  character*132 inputline,fname
  character*40  desc_str,dummy, k_name_dummy(max_kline)
  character(*), parameter :: func = 'read_kpoint'
  logical       flag_skip
  external      nitems
  type(kpoints) :: PKPTS
  type(poscar)  :: PGEOM
  type(incar )  :: PINPT
  PKPTS%flag_cartesianK = .false.
  PKPTS%flag_reciprocal = .false.
  PKPTS%flag_kgridmode  = .false.
  PKPTS%flag_klinemode  = .false.

  write(message,*)' '  ; write_msg
  write(message,*)'*- READING KPOINTS FILE: ',trim(fname)  ; write_msg
  open (pid_kpoint, FILE=fname,iostat=i_continue)
  linecount = 0 

 line: do
        read(pid_kpoint,'(A)',iostat=i_continue) inputline
        if(i_continue<0) exit               ! end of file reached
        if(i_continue>0) then
          write(message,*)'Unknown error reading file:',trim(fname),func  ; write_msg
        endif
        linecount = linecount + 1
        call check_comment(inputline,linecount,i,flag_skip) ; if (flag_skip ) cycle
        call check_empty(inputline,linecount,i,flag_skip) ; if(flag_skip) cycle

        if(i_continue .ne. 0) cycle              ! skip empty line

        ! head
         if(linecount .eq. 1) then
           cycle

        ! dividing factor
         elseif(linecount .eq. 2) then
           PKPTS%n_ndiv = nitems(inputline)
           read(inputline,*,iostat=i_continue) ndiv_temp
           if(ndiv_temp .ne. 0) then
             if(.not. allocated(PKPTS%ndiv)) allocate( PKPTS%ndiv(PKPTS%n_ndiv) )
             read(inputline,*,iostat=i_continue) PKPTS%ndiv(1:PKPTS%n_ndiv)
             if(PKPTS%n_ndiv .gt. 1) PINPT%kline_type = 'FHI-AIMS' ! enforce 
           endif
           cycle

        ! k-grid or -line mode
         elseif(linecount .eq. 3) then
           read(inputline,*,iostat=i_continue) desc_str
           if(desc_str(1:1) .eq. 'L' .or. desc_str(1:1) .eq. 'l') then
             write(message,'(A)')'   K_MODE: Line-mode'  ; write_msg
             PKPTS%flag_klinemode=.true.
             if(.not. PINPT%flag_ndiv_line_parse) then
              !if(.not. allocated(PKPTS%ndiv)) allocate( PKPTS%ndiv(PKPTS%n_ndiv) )
              !PKPTS%ndiv(1) = ndiv_temp
               write(message,'(A,*(I8))')'   #N_DIV: (number of ndiv)',PKPTS%n_ndiv  ; write_msg
               write(message,'(A,*(I8))')'    N_DIV:',PKPTS%ndiv  ; write_msg
             else
               write(message,'(A,*(I8))')'    N_DIV: (set by -nkp_line option) ',PKPTS%ndiv  ; write_msg
             endif
           elseif(desc_str(1:1) .eq. 'G' .or. desc_str(1:1) .eq. 'g') then
             linecount = linecount + 1
             write(message,'(A)')'   K_MODE: Gamma-centered'  ; write_msg
             PKPTS%flag_gamma=.true.
             if(.not. allocated(PKPTS%ndiv)) allocate( PKPTS%ndiv(3) )
           elseif(desc_str(1:1) .eq. 'M' .or. desc_str(1:1) .eq. 'm') then
             linecount = linecount + 1
             write(message,'(A)')'   K_MODE: non Gamma-centered'  ; write_msg
             PKPTS%flag_gamma=.false.
             if(.not. allocated(PKPTS%ndiv)) allocate( PKPTS%ndiv(3) )
           endif

         ! k-vector type
         elseif(linecount .eq. 4) then
           read(inputline,*,iostat=i_continue) desc_str
           if( (desc_str(1:1) .eq. 'R' .or. desc_str(1:1) .eq. 'r') .and. &
                PKPTS%flag_klinemode ) then 
             PKPTS%flag_reciprocal=.true.
             PKPTS%flag_cartesianK=.false.
             write(message,'(A)')'   K_TYPE: Reciprocal unit'  ; write_msg
           elseif( (desc_str(1:1) .eq. 'C' .or. desc_str(1:1) .eq. 'c'  .or.  &
                    desc_str(1:1) .eq. 'K' .or. desc_str(1:1) .eq. 'k') .and. &
                    PKPTS%flag_klinemode ) then
             PKPTS%flag_reciprocal=.false.
             PKPTS%flag_cartesianK=.true.
             write(message,'(A)')'   K_TYPE: Cartesian unit (1/A)'  ; write_msg
           endif

         ! k-grid if .not. 'linemode' .and. 'kgridmode)
         elseif(linecount .eq. 5 .and. .not. PKPTS%flag_klinemode) then
           if(.not. PINPT%flag_ndiv_grid_parse) then
             read(inputline,*,iostat=i_continue) PKPTS%ndiv(1:3)
             write(message,'(A,4x,3I4)')'   K_GRID:',PKPTS%ndiv(1:3)  ; write_msg
           else
             read(inputline,*,iostat=i_continue) i_dummy, i_dummy, i_dummy
             write(message,'(A,4x,3I4)')'   K_GRID: (set by -nkp_grid option)',PKPTS%ndiv(1:3)  ; write_msg
           endif
           PKPTS%flag_kgridmode=.true.
         elseif(linecount .eq. 6 .and. .not. PKPTS%flag_klinemode) then
           read(inputline,*,iostat=i_continue) PKPTS%k_shift(1:3)
           write(message,'(A,4x,3F9.5)')'  K_SHIFT:',PKPTS%k_shift(1:3)  ; write_msg

         ! k-line if 'linemode'
         elseif(linecount .ge. 5 .and. PKPTS%flag_klinemode) then
           backspace(pid_kpoint)
           PKPTS%nline=0;i=0
    kline: do 
             read(pid_kpoint,'(A)',iostat=i_continue) inputline
             if(i_continue<0) exit               ! end of file reached
             if(i_continue>0) then
               write(message,*)'Unknown error reading file:',trim(fname),func  ; write_msg
             endif
             linecount = linecount+1 ; i=i+1
             call check_comment(inputline,linecount,i,flag_skip) ; if (flag_skip ) cycle kline
             call check_empty(inputline,linecount,i,flag_skip) ; if (flag_skip) cycle kline
             read(inputline,*,iostat=i_continue) kline_dummy(1:3,i),k_name_dummy(i)
             if( mod(i,2) .eq. 1 .and. i .ge. 1) then
               PKPTS%nline = PKPTS%nline + 1
               write(message,'(A,I2,A,4x,3F12.8,1x,A2)')' K_LINE',PKPTS%nline,': ',kline_dummy(1:3,i),trim(k_name_dummy(i))  !; write_msg
             elseif( mod(i,2) .eq. 0 .and. i .ge. 1 ) then
               write(message,'(2A,3F12.8,1x,A2)')trim(message), '  --> ', kline_dummy(1:3,i),trim(k_name_dummy(i))  ; write_msg
             endif
           enddo kline
           write(message,'(A,I8)')'   N_LINE:',PKPTS%nline  ; write_msg
           if(PKPTS%nline .ne. PKPTS%n_ndiv .and. (PINPT%kline_type .eq. 'FHI-AIMS' .or. PINPT%kline_type .eq. 'FHI-aims' )) then
             write(message,'(A,I0,A,I0,A)')'   !WARN! You specified ',PKPTS%nline, ' k-path in your KFILE, but it is mismatch with the variable (#N_DIV= ', PKPTS%n_ndiv,') in second line of your KFILE'  ; write_msg
             write(message,'(2A)')         '          Please check your KFILE: ',PINPT%kfilenm   ; write_msg
             kill_job
           endif
           allocate( PKPTS%kline(3,PKPTS%nline * 2) )
           allocate( PKPTS%k_name(PKPTS%nline * 2) )
           PKPTS%kline(1:3,1:PKPTS%nline*2) = kline_dummy(1:3,1:PKPTS%nline * 2)
           PKPTS%k_name(1:PKPTS%nline*2) = k_name_dummy(1:PKPTS%nline * 2)
         endif

      enddo line

  if (linecount == 0) then
    write(message,*)'Attention - empty input file: INCAR-TB ',func  ; write_msg
    stop
  endif
  close(pid_kpoint)

  if(PKPTS%flag_klinemode .and. .not. PKPTS%flag_kgridmode) then
     if(PINPT%kline_type .eq. 'FLEUR' .or. PINPT%kline_type .eq. 'fleur') then
       idiv_mode = 2 ! division type: fleur-like. n division between kpoint A and B and total n+1 points
     elseif(PINPT%kline_type .eq. 'FHI-AIMS' .or. PINPT%kline_type .eq. 'FHI-aims') then
       idiv_mode = 3 ! division type: vasp-like with n-1 division between each segments. In this mode, however, 
                     ! every path has different division. This is same as FHI-AIMS code does.
     else
       idiv_mode = 1 ! division type: vasp-like. n-1 division between kpoint A and B and total n points
     endif
     call get_kpath(PKPTS, PGEOM, PKPTS%kunit, idiv_mode)
     write(message,'(A,I8)')'  NKPOINT:',PKPTS%nkpoint  ; write_msg
  elseif(PKPTS%flag_kgridmode .and. .not. PKPTS%flag_klinemode) then
     PKPTS%nkpoint = PKPTS%ndiv(1)*PKPTS%ndiv(2)*PKPTS%ndiv(3)
     write(message,'(A,I8)')'  NKPOINT:',PKPTS%nkpoint  ; write_msg
     allocate( kpts_cart(3,PKPTS%nkpoint) )
     allocate( kpts_reci(3,PKPTS%nkpoint) )
     allocate( PKPTS%kpoint(3,PKPTS%nkpoint) )
     allocate( PKPTS%kpoint_reci(3,PKPTS%nkpoint) )
     call get_kgrid(kpts_cart, kpts_reci, PKPTS%ndiv(1), PKPTS%ndiv(2), PKPTS%ndiv(3), PKPTS%k_shift(1:3), PGEOM, PKPTS%flag_gamma)
     PKPTS%kpoint(:,:)=kpts_cart(:,:)
     PKPTS%kpoint_reci(:,:)=kpts_reci(:,:)
     deallocate( kpts_cart )
     deallocate( kpts_reci )
  elseif(PKPTS%flag_kgridmode .and. PKPTS%flag_klinemode) then
     write(message,'(A)')'   !WARN! Check KPOINT file. Both linemode and MP mode set simulatneously. Exit..'  ; write_msg
     stop
  elseif( .not. PKPTS%flag_kgridmode .and. .not. PKPTS%flag_klinemode) then
     write(message,'(A)')'   !WARN! Check KPOINT file. Both linemode & MP mode does not set. Exit..'  ; write_msg
     stop
  endif

  write(message,*)'*- END READING KPOINT FILE ---------------------'  ; write_msg
  write(message,*)' '  ; write_msg
return
endsubroutine

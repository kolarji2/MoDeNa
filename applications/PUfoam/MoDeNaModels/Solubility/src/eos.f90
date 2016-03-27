!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! SUBROUTINE FUGACITY
!
! This subroutine serves as an interface to the eos-subroutines.
! (1) case 1, when ensemble_flag = 'tp'
!     The subroutine gives the residual chemical potential:
!      mu_i^res(T,p,x)/kT = ln( phi_i )
!     and in addition, the densities that satisfy the specified p
! (2) case 2, when ensemble_flag = 'tv'
!     The subroutine gives the residual chemical potential:
!     -->   mu_i^res(T,rho,x)/kT
!     and in addition the resulting pressure for the given density.
! The term "residual" means difference of the property and the same
! property for an ideal gas mixture.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE FUGACITY (ln_phi)

  USE BASIC_VARIABLES, only: nc, np, eos, nphas, ncomp, xi, dense, densta, p_cal,  &
                             z_cal, my_cal, rhoi_cal, f_res, gibbs, ensemble_flag
  USE EOS_VARIABLES, ONLY: phas, x, t, eta, eta_start, lnphi, fres, rho, pges, KBOL
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  REAL, INTENT(OUT)                      :: ln_phi(np,nc)

  !-----------------------------------------------------------------------------
  INTEGER                                :: i, ph
  LOGICAL                                :: trivial_result
  !-----------------------------------------------------------------------------

  IF (eos < 2) THEN

     DO ph = 1,nphas

        phas = ph
        eta_start = densta(ph)
        x(1:ncomp)   = xi(ph,1:ncomp)

        CALL CHECK_EOS_VARIABLES ( trivial_result )
        IF ( trivial_result ) return

        !-----------------------------------------------------------------------
        ! calculate chemical potential and other quantities
        !-----------------------------------------------------------------------

        CALL phi_eos_interface

        !-----------------------------------------------------------------------
        ! densities, pressure and Z
        !-----------------------------------------------------------------------
        dense(ph) = eta
        rhoi_cal(ph,1:ncomp) = rho * x(1:ncomp)

        p_cal(ph) = pges
        z_cal(ph) = pges / ( KBOL*1.E30 * t * rho )

        !-----------------------------------------------------------------------
        ! chemical potential / kT and ln( fugacity coefficient )
        !-----------------------------------------------------------------------
        ln_phi(ph,1:ncomp) = lnphi(1:ncomp)

        do i = 1,ncomp
           if ( ( x(i) * rho ) > 1.E-200 ) then
              my_cal( ph, i ) = lnphi( i ) + log( x(i) * rho )
           else
              my_cal( ph, i ) = - 1.E200
           end if
        end do
        if ( ensemble_flag == 'tp' ) my_cal(ph,1:ncomp) = my_cal(ph,1:ncomp) + LOG(z_cal(ph))

        !-----------------------------------------------------------------------
        ! Gibbs energy / kT   and   Helmholtz energy density / kT ( not Helmholtz energy!)
        !-----------------------------------------------------------------------
        gibbs(ph) = sum( x(1:ncomp) * lnphi(1:ncomp) )
        f_res(ph) = fres * rho
        do i = 1,ncomp
          if ( x(i) > 1.E-200 ) gibbs(ph) = gibbs(ph) + x(i) * log( x(i)*rho )
          if ( x(i) > 1.E-200 ) f_res(ph) = f_res(ph) + x(i) * rho * ( log( x(i)*rho) - 1.0 )
        end do
        if ( ensemble_flag == 'tp' ) gibbs(ph) = gibbs(ph) + LOG( z_cal(ph) )

        ! write (*,'(i3,4G20.11)') ph,eta,lnphi(1),lnphi(2),x(1)
        ! DO i = 1,ncomp
        !   DO j=1,NINT(parame(i,12))
        !     mxx(ph,i,j) = mx(i,j)
        !   END DO
        ! END DO

     END DO

  ELSE

     !  IF (eos == 2) CALL srk_eos (ln_phi)
     !  IF (eos == 3) CALL  pr_eos (ln_phi)
     !  dense(1) = 0.01
     !  dense(2) = 0.3
     !  IF (eos == 4.OR.eos == 5.OR.eos == 6.OR.eos == 8) CALL lj_fugacity(ln_phi)
     !  IF (eos == 7) CALL sw_fugacity(ln_phi)
     !  IF (eos == 9) CALL lj_bh_fug(ln_phi)

  END IF

END SUBROUTINE FUGACITY



!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! SUBROUTINE CHECK_EOS_VARIABLES
!
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE CHECK_EOS_VARIABLES ( trivial_result )

  USE BASIC_VARIABLES
  USE EOS_VARIABLES, ONLY: x, eta, eta_start, lnphi, fres, rho, pges, KBOL, z3t
  USE utilities
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  LOGICAL, INTENT(OUT)                   :: trivial_result

  !-----------------------------------------------------------------------------
  INTEGER                                :: i
  REAL                                   :: sum_x
  !-----------------------------------------------------------------------------

  trivial_result = .false.

  !-----------------------------------------------------------------------------
  ! verify specification: either (T,p,x) or (T,rho,x)-variables
  !-----------------------------------------------------------------------------

  IF ( ensemble_flag /= 'tp' .AND. ensemble_flag /= 'tv' ) THEN
     WRITE(*,*) ' FUGACITY: variable ensemble_flag is undefined ',ensemble_flag
     stop
  END IF

  !-----------------------------------------------------------------------------
  ! check for NaN
  !-----------------------------------------------------------------------------

  IF ( eta_start /= eta_start ) THEN
     WRITE(*,*) ' FUGACITY: density input is "not a number" !'
     trivial_result = .true.
  END IF

  DO i = 1, ncomp
     IF ( x(i) /= x(i) ) THEN
        WRITE(*,*) ' FUGACITY: composition input x is "not a number" ! Species:',i
        trivial_result = .true.
     END IF
  END DO

  !-----------------------------------------------------------------------------
  ! verify proper specification of mole fractions x
  !-----------------------------------------------------------------------------

  sum_x = sum( x(1:ncomp) )
  IF ( sum_x /= 1.0 ) THEN
     IF ( (sum_x - 1.0 ) < 1.E-4 .AND. (sum_x - 1.0 ) > -1.E-4 ) THEN
        x( 1:ncomp ) = x( 1:ncomp ) / sum_x
        ! WRITE(*,*) ' FUGACITY: rescale composition',sum_x, x(1:ncomp)
     END IF
  END IF

  !-----------------------------------------------------------------------------
  ! if sum is not unity within 10.E-8, then at this point, the sum has to be
  ! outside of 10.E-4 bandwidth
  !-----------------------------------------------------------------------------
  sum_x = sum( x(1:ncomp) )
  IF ( (sum_x - 1.0 ) > 1.E-8 .OR. (sum_x - 1.0 ) < -1.E-8 ) THEN
     ! WRITE(*,*) ' FUGACITY: composition not properly defined',sum( x(1:ncomp) )
     if ( sum( x(1:ncomp) ) < 0.2 ) x(1:ncomp) = x(1:ncomp) / sum( x(1:ncomp) )
     ! call pause
  END IF

  IF ( MINVAL( x(1:ncomp) ) < 0.0 ) THEN
     WRITE(*,*) ' FUGACITY: mole fraction x is negative, of species', MINLOC(x(1:ncomp))
     stop
  END IF
  DO i = 1, ncomp
     IF ( x(i) < 1.E-50 ) x(i) = 0.0
  END DO

  !-----------------------------------------------------------------------------
  ! verify proper specification of either pressure (p), or of density (eta)
  !-----------------------------------------------------------------------------

  IF ( ensemble_flag == 'tp' .AND. p < 1.E-100 ) THEN
     WRITE(*,*) ' FUGACITY: PRESSURE TOO LOW', p
     p = 1.E-6
  END IF

  IF ( ensemble_flag == 'tv' .AND. eta_start < 1.E-100 ) THEN
     WRITE(*,*) ' FUGACITY: DENSITY TOO LOW', eta_start
     eta = 1.E-100
     trivial_result = .true.
  END IF

  !-----------------------------------------------------------------------------
  ! for too low density, don't execute the subroutine PHI_EOS
  !-----------------------------------------------------------------------------

  IF ( trivial_result ) THEN
     CALL PERTURBATION_PARAMETER
     rho = eta / z3t
     pges = KBOL*1.E30 * t * rho
     lnphi(1:ncomp) = 1.0
     fres = 0.0
  END IF

END SUBROUTINE CHECK_EOS_VARIABLES


!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! subroutine p_eos_interface
!
! This subroutine serves as interface to the different versions of the PC-SAFT eos.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

subroutine p_eos_interface

  use BASIC_VARIABLES, only: num
  use EOS_VARIABLES
  use EOS_NUMERICAL

  IF (num == 0) THEN
    CALL P_EOS
  ELSE IF (num == 1) THEN
    CALL P_NUMERICAL
  ELSE IF (num == 2) THEN
    CALL F_EOS_RN
  ELSE
    write (*,*) 'p_eos_interface: define calculation option (num)'
  END IF

end subroutine p_eos_interface


!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! subroutine f_eos_interface
!
! This subroutine serves as interface to the different versions of the PC-SAFT eos.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

subroutine f_eos_interface

  use BASIC_VARIABLES, only: num
  use EOS_VARIABLES
  use EOS_NUMERICAL

  IF (num == 0) THEN
     CALL F_EOS
  ELSE IF (num == 1) THEN
    CALL F_NUMERICAL
  ELSE IF (num == 2) THEN
    CALL F_EOS_RN
  ELSE
    write (*,*) 'f_eos_interface: define calculation option (num)'
  END IF


end subroutine f_eos_interface


!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! subroutine phi_eos_interface
!
! This subroutine serves as interface to the different versions of the PC-SAFT eos.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

subroutine phi_eos_interface

  use BASIC_VARIABLES, only: num
  use EOS_VARIABLES
  use EOS_NUMERICAL

  IF (num == 0) THEN
    CALL PHI_EOS
  ELSE IF (num == 1) THEN
    CALL PHI_NUMERICAL
  ELSE IF (num == 2) THEN
    CALL PHI_CRITICAL_RENORM
  ELSE
    write (*,*) 'phi_eos_interface: define calculation option (num)'
  END IF

end subroutine phi_eos_interface


!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! subroutine h_eos_interface
!
! This subroutine serves as interface to the different versions of the PC-SAFT eos.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

subroutine h_eos_interface

  use BASIC_VARIABLES, only: num
  use EOS_VARIABLES
  use EOS_NUMERICAL

  IF (num == 0) THEN
    CALL H_EOS
  ELSE IF (num == 1) THEN
    CALL H_NUMERICAL
  ELSE IF (num == 2) THEN
    write (*,*) 'enthalpy_etc: incorporate H_EOS_RN'
    stop
    ! CALL H_EOS_rn
  ELSE
    write (*,*) 'phi_eos_interface: define calculation option (num)'
  END IF

end subroutine h_eos_interface


!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! SUBROUTINE PHI_EOS
!
! This subroutine gives the residual chemical potential:
! -->   mu_i^res(T,p,x)/kT = ln( phi_i )       when ensemble_flag = 'tp'
! The required input for this case (T, p, x(nc)) and as a starting value
! eta_start
!
! or it gives
!
! -->   mu_i^res(T,rho,x)/kT                   when ensemble_flag = 'tv'
! The required input for this case (T, eta_start, x(nc)). Note that
! eta_start is the specified density (packing fraction) in this case.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE PHI_EOS

  USE PARAMETERS
  USE EOS_VARIABLES
  USE EOS_CONSTANTS
  USE EOS_POLAR, only: phi_polar
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  INTEGER                                :: i, j, k, ii, jj, kk, m
  REAL                                   :: z0, z1, z2, z3, z0_rk, z1_rk, z2_rk, z3_rk
  REAL                                   :: ome, ome2, ome3, m_mean
  REAL, DIMENSION(nc)                    :: mhs, mdsp, mhc, myres
  REAL                                   :: z3_m
  REAL                                   :: m_rk
  REAL                                   :: gij_rk(nc,nc)
  REAL                                   :: zres, zges
  REAL                                   :: dpdz, dpdz2

  REAL                                   :: I1, I2, I1_rk, I2_rk
  REAL                                   :: ord1_rk, ord2_rk
  REAL                                   :: c1_con, c2_con, c1_rk
  REAL, DIMENSION(nc,0:6)                :: ap_rk, bp_rk

  LOGICAL                                :: assoc
  REAL                                   :: ass_s2, m_hbon(nc)

  REAL                                   :: fdd_rk, fqq_rk, fdq_rk
  REAL, DIMENSION(nc)                    :: my_dd, my_qq, my_dq
  !-----------------------------------------------------------------------------

  !-----------------------------------------------------------------------------
  ! obtain parameters and density independent expressions
  !-----------------------------------------------------------------------------
  CALL PERTURBATION_PARAMETER


  !-----------------------------------------------------------------------------
  ! density iteration: (pTx)-ensemble   OR   p calc.: (pvx)-ensemble
  !-----------------------------------------------------------------------------
  IF ( ensemble_flag == 'tp' ) THEN
     CALL DENSITY_ITERATION
  ELSEIF ( ensemble_flag == 'tv' ) THEN
     eta = eta_start
     CALL P_EOS
  END IF

  ! --- Eq.(A.8) ---------------------------------------------------------------
  rho = eta / z3t
  IF ( rho /= rho ) write (*,*) 'PHI_EOS: error in density',eta, z3t
  IF ( rho /= rho ) stop
  z0  = z0t * rho
  z1  = z1t * rho
  z2  = z2t * rho
  z3  = z3t * rho

  m_mean = z0t / (PI/6.0)
  ome  = 1.0 - eta
  ome2 = ome * ome
  ome3 = ome * ome2

  !-----------------------------------------------------------------------------
  ! compressibility factor z = p/(kT*rho)
  !-----------------------------------------------------------------------------
  zges = (p * 1.E-30) / (KBOL*t*rho)
  IF ( ensemble_flag == 'tv' ) zges = (pges * 1.E-30) / (KBOL*t*rho)
  zres = zges - 1.0



  !=============================================================================
  ! calculate the derivatives of f to mole fraction x ( d(f)/d(rho_k) )
  !=============================================================================

  DO  k = 1, ncomp

     z0_rk = PI/6.0 * mseg(k)
     z1_rk = z0_rk * dhs(k)
     z2_rk = z1_rk * dhs(k)
     z3_rk = z2_rk * dhs(k)

     ! --- derivative d(m_mean)/d(rho_k) ---------------------------------------
     m_rk = ( mseg(k) - m_mean ) / rho
     ! lij(1,2)= -0.050
     ! lij(2,1)=lij(1,2)
     ! r_m2dx(k)=0.0
     ! m_mean2=0.0
     ! DO i =1,ncomp
     !    r_m2dx(k)=r_m2dx(k)+2.0*x(i)*(mseg(i)+mseg(k))/2.0*(1.0-lij(i,k))
     !    DO j =1,ncomp
     !       m_mean2=m_mean2+x(i)*x(j)*(mseg(i)+mseg(j))/2.0*(1.0-lij(i,j))
     !    ENDDO
     ! ENDDO

     !--------------------------------------------------------------------------
     ! d(f)/d(rho_k) : hard sphere contribution
     !--------------------------------------------------------------------------
     if ( z3**3 > 0.0 ) then
        mhs(k) =  6.0/PI* (  3.0*(z1_rk*z2+z1*z2_rk)/ome + 3.0*z1*z2*z3_rk/ome2  &
             + 3.0*z2*z2*z2_rk/z3/ome2 + z2**3 *z3_rk*(3.0*z3-1.0)/z3/z3/ome3   &
             + ((3.0*z2*z2*z2_rk*z3-2.0*z2**3 *z3_rk)/z3**3 -z0_rk) *LOG(ome)  &
             + (z0-z2**3 /z3/z3)*z3_rk/ome  )
     end if

     !--------------------------------------------------------------------------
     ! d(f)/d(rho_k) : chain term
     !--------------------------------------------------------------------------
     DO i = 1, ncomp
        DO j = 1, ncomp
           gij(i,j) = 1.0/ome + 3.0*dij_ab(i,j)*z2/ome2 + 2.0*(dij_ab(i,j)*z2)**2 /ome3
           gij_rk(i,j) = z3_rk/ome2  &
                + 3.0*dij_ab(i,j)*(z2_rk+2.0*z2*z3_rk/ome)/ome2  &
                + dij_ab(i,j)**2 *z2/ome3  *(4.0*z2_rk+6.0*z2*z3_rk/ome)
        END DO
     END DO

     mhc(k) = 0.0
     DO i = 1, ncomp
        mhc(k) = mhc(k) + x(i)*rho * (1.0-mseg(i)) / gij(i,i) * gij_rk(i,i)
     END DO
     mhc(k) = mhc(k) + ( 1.0-mseg(k)) * LOG( gij(k,k) )


     !--------------------------------------------------------------------------
     ! PC-SAFT:  d(f)/d(rho_k) : dispersion contribution
     !--------------------------------------------------------------------------

     ! --- derivatives of apar, bpar to rho_k -------------------------------
     DO m = 0, 6
        ap_rk(k,m) = m_rk/m_mean**2 * ( ap(m,2) + (3.0 -4.0/m_mean) *ap(m,3) )
        bp_rk(k,m) = m_rk/m_mean**2 * ( bp(m,2) + (3.0 -4.0/m_mean) *bp(m,3) )
     END DO

     I1    = 0.0
     I2    = 0.0
     I1_rk = 0.0
     I2_rk = 0.0
     DO m = 0, 6
        z3_m = eta**m
        I1  = I1 + apar(m) * z3_m
        I2  = I2 + bpar(m) * z3_m
        I1_rk = I1_rk + apar(m) * REAL(m) * eta**(m-1) * z3_rk + ap_rk(k,m) * z3_m
        I2_rk = I2_rk + bpar(m) * REAL(m) * eta**(m-1) * z3_rk + bp_rk(k,m) * z3_m
     END DO

     ord1_rk  = 0.0
     ord2_rk  = 0.0
     DO i = 1,ncomp
        ord1_rk = ord1_rk + 2.0*mseg(k)*rho*x(i)*mseg(i)*sig_ij(i,k)**3  *uij(i,k)/t
        ord2_rk = ord2_rk + 2.0*mseg(k)*rho*x(i)*mseg(i)*sig_ij(i,k)**3 *(uij(i,k)/t)**2
     END DO

     c1_con= 1.0/ (  1.0 + m_mean*(8.0*z3-2.0*z3*z3)/ome2/ome2   &
          + (1.0 - m_mean)*(20.0*z3-27.0*z3*z3 +12.0*z3**3 -2.0*z3**4 )  &
          /(ome*(2.0-z3))**2  )
     c2_con= - c1_con*c1_con *(  m_mean*(-4.0*z3*z3+20.0*z3+8.0)/ome2/ome3   &
          + (1.0 - m_mean) *(2.0*z3**3 +12.0*z3*z3-48.0*z3+40.0)  &
          /(ome*(2.0-z3))**3  )
     c1_rk= c2_con*z3_rk - c1_con*c1_con*m_rk   *  ( (8.0*z3-2.0*z3*z3)/ome2/ome2   &
          - (-2.0*z3**4 +12.0*z3**3 -27.0*z3*z3+20.0*z3) / (ome*(2.0-z3))**2  )

     mdsp(k) = -2.0*PI* ( order1*rho*rho*I1_rk + ord1_rk*I1 )  &
          -    PI* c1_con*m_mean * ( order2*rho*rho*I2_rk + ord2_rk*I2 )  &
          -    PI* ( c1_con*m_rk + c1_rk*m_mean ) * order2*rho*rho*I2


     !--------------------------------------------------------------------------
     ! TPT-1-association according to Chapman et al.
     !--------------------------------------------------------------------------
     m_hbon(k) = 0.0
     assoc = .false.
     DO i = 1,ncomp
        IF (nhb_typ(i) /= 0) assoc = .true.
     END DO
     IF (assoc) THEN

        ass_s2  = 0.0
        DO kk = 1, nhb_typ(k)
           ass_s2  = ass_s2  + nhb_no(k,kk) * LOG(mx(k,kk))
        END DO

        m_hbon(k)=ass_s2
        DO i = 1, ncomp
           DO ii = 1, nhb_typ(i)
              DO j = 1, ncomp
                 DO jj = 1, nhb_typ(j)
                    m_hbon(k) = m_hbon(k) - rho * rho / 2.0 * x(i) * x(j) * mx(i,ii) * mx(j,jj)  &
                         * nhb_no(i,ii)*nhb_no(j,jj) *gij_rk(i,j) *ass_d(i,j,ii,jj)
                 END DO
              END DO
           END DO
        END DO

     END IF


     !--------------------------------------------------------------------------
     ! polar terms
     !--------------------------------------------------------------------------
     CALL PHI_POLAR ( k, z3_rk, fdd_rk, fqq_rk, fdq_rk )
     my_dd(k) = fdd_rk
     my_qq(k) = fqq_rk
     my_dq(k) = fdq_rk


     !--------------------------------------------------------------------------
     ! d(f)/d(rho_k) : summation of all contributions
     !--------------------------------------------------------------------------
     myres(k) = mhs(k) +mhc(k) +mdsp(k) +m_hbon(k) +my_dd(k) +my_qq(k) +my_dq(k)

  END DO


  !-----------------------------------------------------------------------------
  ! finally calculate
  ! mu_i^res(T,p,x)/kT = ln( phi_i )       when ensemble_flag = 'tp'
  ! mu_i^res(T,rho,x)/kT                   when ensemble_flag = 'tv'
  !-----------------------------------------------------------------------------

  DO k = 1, ncomp
     ! write (*,*) k,myres(k) +LOG(rho*x(k)),rho*32000.0
     IF (ensemble_flag == 'tp' ) lnphi(k) = myres(k) - LOG(zges)
     IF (ensemble_flag == 'tv' ) lnphi(k) = myres(k)
     ! write (*,*) 'in',k,lnphi(k),LOG(zges),eta
  END DO
  ! write (*,'(a,5G18.10)') 'fug.coeff.lnphi 1,2',lnphi(1),lnphi(2),rho

  dpdz  = pgesdz
  dpdz2 = pgesd2

  tfr= mhs(1)


END SUBROUTINE PHI_EOS




!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! SUBROUTINE ddA_dhoi_drhoi_EOS
!
! This subroutine gives the second derivatives
!       dd( F/VkT ) / d(rhoi)d(rhoi)
! The variables are (T, rhoi), corrsponding to a case: ensemble_flag = 'tv'
! The required input is (T, rho, x(nc)).
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE ddA_drhoi_drhoj_EOS ( n_comp, rhoi, A_rr, Aig_rr )

  USE PARAMETERS
  USE EOS_VARIABLES
  USE EOS_CONSTANTS
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  integer, intent(in)                    :: n_comp
  real, dimension(n_comp), intent(in)    :: rhoi
  real, dimension(n_comp,n_comp), intent(out) :: A_rr
  real, dimension(n_comp,n_comp), intent(out) :: Aig_rr

  !-----------------------------------------------------------------------------
  integer                                :: i, j, k, l, m
  integer                                :: n_dim, m_dim
  integer                                :: ii, jj, ll, iii, jjj, kk, lll
  real                                   :: z0, z1, z2, z3
  real, allocatable, dimension(:)        :: z0_r, z1_r, z2_r, z3_r
  real                                   :: m_mean
  real                                   :: ome, ome2, ome3, PI_6
  real                                   :: Ahs_rkrl, Ahc_rkrl, Adsp_rkrl
  real, allocatable, dimension(:)        :: m_r
  real                                   :: a_term, b_term, m_rkrl
  real, allocatable, dimension(:,:,:)    :: gij_r
  real, allocatable, dimension(:,:,:,:)  :: gij_rr

  real, allocatable, dimension(:,:)      :: q_XX, q_Xr, q_Xr_transpose, q_rr
  real, allocatable, dimension(:,:)      :: Ahb_rr, A_polar_rr
  real                                   :: determinant

  real, allocatable, dimension(:,:)      :: ap_r, bp_r
  real, dimension(0:6)                   :: ap_rkrl, bp_rkrl
  real                                   :: I1, I2
  real, allocatable, dimension(:)        :: I1_r, I2_r
  real                                   :: I1_rkrl, I2_rkrl
  real, allocatable, dimension(:)        :: ord1_r, ord2_r
  real                                   :: ord1_rkrl, ord2_rkrl
  real                                   :: eta_m, aux_term_k
  real                                   :: c1_con, c2_con, c3_con, c2_dm
  real, allocatable, dimension(:)        :: c1_r
  real                                   :: c1_rkrl
  real                                   :: chi_dm, chi_dmdeta

  logical                                :: assoc
  !-----------------------------------------------------------------------------

  allocate( z0_r(ncomp), z1_r(ncomp), z2_r(ncomp), z3_r(ncomp) )
  allocate( gij_r(ncomp,ncomp,ncomp) )
  allocate( gij_rr(ncomp,ncomp,ncomp,ncomp) )
  allocate( m_r(ncomp) )
  allocate( ap_r(ncomp,0:6), bp_r(ncomp,0:6) )
  allocate( I1_r(ncomp), I2_r(ncomp) )
  allocate( ord1_r(ncomp), ord2_r(ncomp) )
  allocate( c1_r(ncomp) )
  allocate( A_polar_rr( ncomp, ncomp ) )

  rho = sum( rhoi(1:ncomp) )
  x(1:ncomp) = rhoi(1:ncomp) / rho

  !-----------------------------------------------------------------------------
  ! obtain parameters and density independent expressions
  !-----------------------------------------------------------------------------
  CALL PERTURBATION_PARAMETER

  IF ( rho /= rho ) write (*,*) 'ddA_dhoi_drhoi_EOS: error in density',eta, z3t
  IF ( rho /= rho ) stop
  ! rhoi( 1:ncomp ) = x(1:ncomp ) * rho
  z0  = z0t * rho
  z1  = z1t * rho
  z2  = z2t * rho
  z3  = z3t * rho
  eta = z3

  m_mean = z0t / (PI/6.0)
  ome    = 1.0 - z3
  ome2 = ome * ome
  ome3 = ome * ome2

  PI_6 = PI/6.0

  !=============================================================================
  ! calculate the derivatives of f to rho_k ( d(f)/d(rho_k) )
  !=============================================================================

  c1_con= 1.0/ (  1.0 + m_mean*(8.0*z3-2.0*z3*z3)/ome2/ome2   &
       + (1.0 - m_mean)*(20.0*z3-27.0*z3*z3 +12.0*z3**3 -2.0*z3**4 )  &
       /(ome*(2.0-z3))**2  )
  c2_con= - c1_con*c1_con *(  m_mean*(-4.0*z3*z3+20.0*z3+8.0)/ome**5   &
       + (1.0 - m_mean) *(2.0*z3**3 +12.0*z3*z3-48.0*z3+40.0)  &
       /(ome*(2.0-z3))**3  )
  c3_con= 2.0 * c2_con*c2_con/c1_con - c1_con*c1_con  &
       *( m_mean*(-12.0*eta**2 +72.0*eta+60.0)/ome**6   &
       + (1.0 - m_mean)  &
       *(-6.0*eta**4 -48.0*eta**3 +288.0*eta**2   &
       -480.0*eta+264.0) /(ome*(2.0-eta))**4  )
  chi_dm = (8.0*z3-2.0*z3*z3)/ome**4   &
       - (-2.0*z3**4 +12.0*z3**3 -27.0*z3*z3+20.0*z3) / (ome*(2.0-z3))**2
  chi_dmdeta = (-4.0*z3*z3+20.0*z3+8.0)/ome**5  &
       - (2.0*z3**3 +12.0*z3*z3-48.0*z3+40.0) / (ome*(2.0-z3))**3
  c2_dm = - 2.0*c2_con*c1_con*chi_dm - c1_con*c1_con*chi_dmdeta

  DO  k = 1, ncomp

     z0_r(k) = PI_6 * mseg(k)
     z1_r(k) = z0_r(k) * dhs(k)
     z2_r(k) = z1_r(k) * dhs(k)
     z3_r(k) = z2_r(k) * dhs(k)

     DO i = 1, ncomp
        DO j = 1, ncomp
           gij(i,j) = 1.0/ome + 3.0*dij_ab(i,j)*z2/ome2 + 2.0*(dij_ab(i,j)*z2)**2 /ome3
           gij_r(k,i,j) = z3_r(k)/ome2  &
                + 3.0*dij_ab(i,j)*(z2_r(k)+2.0*z2*z3_r(k)/ome)/ome2  &
                + dij_ab(i,j)**2 *z2/ome3  *(4.0*z2_r(k)+6.0*z2*z3_r(k)/ome)
        END DO
     END DO

     m_r(k) = ( mseg(k) - m_mean ) / rho

     DO m = 0, 6
        a_term = ( ap(m,2) + (3.0 -4.0/m_mean) *ap(m,3) ) / m_mean/m_mean
        b_term = ( bp(m,2) + (3.0 -4.0/m_mean) *bp(m,3) ) / m_mean/m_mean
        ap_r(k,m) = m_r(k) * a_term
        bp_r(k,m) = m_r(k) * b_term
     END DO

     I1 = 0.0
     I2 = 0.0
     I1_r(k) = 0.0
     I2_r(k) = 0.0
     DO m = 0, 6
        eta_m = eta**m
        I1  = I1 + apar(m) * eta_m
        I2  = I2 + bpar(m) * eta_m
        I1_r(k) = I1_r(k) + apar(m) * real(m) * eta**(m-1) * z3_r(k) + ap_r(k,m) * eta_m
        I2_r(k) = I2_r(k) + bpar(m) * real(m) * eta**(m-1) * z3_r(k) + bp_r(k,m) * eta_m
     END DO

     ord1_r(k) = 0.0
     ord2_r(k) = 0.0
     DO i = 1,ncomp
        aux_term_k = 2.0*mseg(k)*mseg(i)*sig_ij(i,k)**3  *uij(i,k)/t
        ord1_r(k) = ord1_r(k) + rhoi(i) * aux_term_k
        ord2_r(k) = ord2_r(k) + rhoi(i) * aux_term_k * uij(i,k)/t
     END DO

     c1_r(k)= c2_con*z3_r(k) - c1_con*c1_con * chi_dm * m_r(k)

  end do

  do k = 1, ncomp
     do l = 1, ncomp
        DO i = 1, ncomp
           DO j = 1, ncomp
              gij_rr(k,l,i,j) = 2.0*z3_r(k)*z3_r(l)/ome3  &
                   + 6.0*dij_ab(i,j)*( z2_r(k)*z3_r(l)+z2_r(l)*z3_r(k)+3.0*z2*z3_r(k)*z3_r(l)/ome ) /ome3  &
                   +dij_ab(i,j)**2/ome3 *( 4.0*z2_r(k)*z2_r(l) + 12.0*z2*(z2_r(k)*z3_r(l)+z2_r(l)*z3_r(k))/ome  &
                   + 24.0*z2*z2*z3_r(k)*z3_r(l)/ome2 )
           END DO
        END DO
     end do
  end do


  !=============================================================================
  ! calculate the derivatives of f to rho_k and rho_l ( dd(f)/d(rho_k)d(rho_l) )
  !=============================================================================

  DO  k = 1, ncomp

  DO  l = 1, ncomp

     !--------------------------------------------------------------------------
     ! d(f)/d(rho_k) : hard sphere contribution
     !--------------------------------------------------------------------------
     if ( z3**4 > 0.0 ) then
        Ahs_rkrl = ( 3.0*(z1_r(k)*z2_r(l)+z1_r(l)*z2_r(k))/ome + 3.0*(z1_r(k)*z2+z1*z2_r(k))*z3_r(l)/ome2  &
             + 3.0*(z1_r(l)*z2+z1*z2_r(l))*z3_r(k)/ome2 + 6.0*z1*z2*z3_r(k)*z3_r(l)/ome3  &
             + 6.0*z2*z2_r(l)*z2_r(k)/z3/ome2 + 3.0*z2*z2*(z2_r(k)*z3_r(l)+z2_r(l)*z3_r(k))*(3.0*z3-1.0)/z3/z3/ome3  &
             + 3.0*z2**3*z3_r(k)*z3_r(l) /z3/z3/ome3   &
             + z2**3*z3_r(k)*z3_r(l)*(3.0*z3-1.0)*(5.0*z3-2.0)/z3**3/ome2/ome2  &
             + ( 6.0*z2*z2*(z2_r(l)/z2*z2_r(k)*z3-z2_r(k)*z3_r(l)-z2_r(l)*z3_r(k)+z2*z3_r(k)*z3_r(l)/z3 )/z3**3 )*LOG(ome)  &
             + ( (2.0*z2*z3_r(k)-3.0*z2_r(k)*z3)*z2*z2/z3**3 + z0_r(k) )*z3_r(l)/ome  &
             + (z0_r(l)-z2*z2*(3.0*z2_r(l)*z3-2.0*z2*z3_r(l))/z3**3)*z3_r(k)/ome  &
             + (z0-z2**3/z3/z3)*z3_r(k)*z3_r(l)/ome2 )   /  PI_6
     else
        Ahs_rkrl = 0.0
     end if


     !--------------------------------------------------------------------------
     ! d(f)/d(rho_k) : chain term
     !--------------------------------------------------------------------------

     Ahc_rkrl = 0.0
     DO i = 1, ncomp
        Ahc_rkrl = Ahc_rkrl + rhoi(i) * (1.0-mseg(i)) / gij(i,i)  &
                                       * ( gij_rr(k,l,i,i) - gij_r(k,i,i)*gij_r(l,i,i)/gij(i,i) )
     END DO
     Ahc_rkrl = Ahc_rkrl + (1.0-mseg(k)) / gij(k,k) * gij_r(l,k,k) + (1.0-mseg(l)) / gij(l,l) * gij_r(k,l,l)


     !--------------------------------------------------------------------------
     ! PC-SAFT:  d(f)/d(rho_k) : dispersion contribution
     !--------------------------------------------------------------------------

     m_rkrl = ( 2.0*m_mean - mseg(k) - mseg(l) ) / rho/rho

     ! --- derivatives of apar, bpar to rho_k -------------------------------
     DO m = 0, 6
        a_term = ( ap(m,2) + (3.0 -4.0/m_mean) *ap(m,3) ) / m_mean/m_mean
        b_term = ( bp(m,2) + (3.0 -4.0/m_mean) *bp(m,3) ) / m_mean/m_mean
        ap_rkrl(m) = m_rkrl * a_term + 2.0/m_mean*m_r(k)*m_r(l)*( 2.0*ap(m,3)/m_mean**3 - a_term )
        bp_rkrl(m) = m_rkrl * b_term + 2.0/m_mean*m_r(k)*m_r(l)*( 2.0*bp(m,3)/m_mean**3 - b_term )
     END DO

     I1_rkrl = 0.0
     I2_rkrl = 0.0
     DO m = 0, 6
        eta_m = eta**m
        I1_rkrl = I1_rkrl + ap_rkrl(m) * eta_m + real(m) *(z3_r(k)*ap_r(l,m)+z3_r(l)*ap_r(k,m)) *eta**(m-1)  &
                  + real(m)*real(m-1)*apar(m)*z3_r(k)*z3_r(l)*eta**(m-2)
        I2_rkrl = I2_rkrl + bp_rkrl(m) * eta_m + real(m) *(z3_r(k)*bp_r(l,m)+z3_r(l)*bp_r(k,m)) *eta**(m-1)  &
                  + real(m)*real(m-1)*bpar(m)*z3_r(k)*z3_r(l)*eta**(m-2)
     END DO

     ord1_rkrl = 2.0*mseg(k)*mseg(l)*sig_ij(k,l)**3  *uij(k,l)/t
     ord2_rkrl = 2.0*mseg(k)*mseg(l)*sig_ij(k,l)**3  * (uij(k,l)/t)**2

     c1_rkrl = c3_con*z3_r(l)*z3_r(k) + c2_dm*m_r(l)*z3_r(k)  &
          - c1_con* ( 2.0*c1_r(l)*chi_dm*m_r(k) + c1_con*chi_dmdeta*z3_r(l)*m_r(k)+ c1_con*chi_dm*m_rkrl)

     Adsp_rkrl = -2.0*PI* ( ord1_rkrl*I1 +ord1_r(k)*I1_r(l)+ord1_r(l)*I1_r(k)+order1*rho*rho*I1_rkrl )  &
          -    PI* ( m_rkrl*c1_con + m_r(k)*c1_r(l)+m_r(l)*c1_r(k)+ m_mean*c1_rkrl ) * order2*rho*rho*I2  &
          -    PI* (m_r(k)*c1_con+m_mean*c1_r(k)) * ( ord2_r(l)*I2 + order2*rho*rho*I2_r(l) )  &
          -    PI* (m_r(l)*c1_con+m_mean*c1_r(l)) * ( ord2_r(k)*I2 + order2*rho*rho*I2_r(k) )  &
          -    PI* m_mean*c1_con * ( ord2_rkrl*I2 +ord2_r(k)*I2_r(l)+ord2_r(l)*I2_r(k)+order2*rho*rho*I2_rkrl)


     !--------------------------------------------------------------------------
     ! second derivative of Helmholtz energy to rho_k and rho_l
     !--------------------------------------------------------------------------

     A_rr(k,l) = Ahs_rkrl + Ahc_rkrl + Adsp_rkrl
     ! write (*,*) k, l, A_rr(k,l)

  end do
  end do

  !-----------------------------------------------------------------------------
  ! TPT-1-association according to Chapman et al.
  !-----------------------------------------------------------------------------
  assoc = .false.
  DO i = 1,ncomp
     IF (nhb_typ(i) /= 0) assoc = .true.
  END DO
  IF (assoc) THEN

     n_dim = 0
     DO i = 1, ncomp
        DO ii = 1, nhb_typ(i)
           n_dim = n_dim + 1
        END DO
     END DO

     m_dim = ncomp

     allocate( q_XX( n_dim, n_dim ) )
     allocate( q_Xr( n_dim, m_dim ) )
     allocate( q_Xr_transpose( m_dim, n_dim ) )
     allocate( q_rr( m_dim, m_dim ) )
     allocate( Ahb_rr( m_dim, m_dim ) )


     iii = 0
     DO i = 1, ncomp
        DO ii = 1, nhb_typ(i)
           iii = iii + 1
           jjj = 0
           DO j = 1, ncomp
              DO jj = 1, nhb_typ(j)
                 jjj = jjj + 1
                 q_XX(iii,jjj) = - rhoi(i) * rhoi(j) * gij(i,j) *ass_d(i,j,ii,jj)
                 if ( iii == jjj ) q_XX(iii,jjj) = q_XX(iii,jjj) - rhoi(i) / ( mx(i,ii) * nhb_no(i,ii) )**2 * nhb_no(i,ii)
              END DO
           END DO
        END DO
     END DO

     do k = 1, ncomp
     lll = 0
     do l = 1, ncomp
        DO ll = 1, nhb_typ(l)
           lll = lll + 1
           q_Xr(lll,k) = 0.0
           DO i = 1, ncomp
              do ii = 1, nhb_typ(i)
                 q_Xr(lll,k) = q_Xr(lll,k) - rhoi(l)*rhoi(i)*mx(i,ii)*nhb_no(i,ii) *gij_r(k,i,l) *ass_d(i,l,ii,ll)
              end do
           END DO
           do kk = 1, nhb_typ(k)
              q_Xr(lll,k) = q_Xr(lll,k) - rhoi(l)* mx(k,kk)*nhb_no(k,kk) *gij(k,l) *ass_d(k,l,kk,ll)
           end do
           q_Xr_transpose(k,lll) = q_Xr(lll,k)
        END DO
     end do
     end do

     q_rr(:,:) = 0.0
     do k = 1, ncomp
     do l = 1, ncomp
     DO i = 1, ncomp
        DO ii = 1, nhb_typ(i)
           DO ll = 1, nhb_typ(l)
              q_rr(k,l) = q_rr(k,l) - rhoi(i) * mx(i,ii)*nhb_no(i,ii)  &
                                      * mx(l,ll)*nhb_no(l,ll) * gij_r(k,i,l) *ass_d(i,l,ii,ll)
           END DO
           DO kk = 1, nhb_typ(k)
              q_rr(k,l) = q_rr(k,l) - rhoi(i) * mx(i,ii)*nhb_no(i,ii)  &
                                      * mx(k,kk)*nhb_no(k,kk) * gij_r(l,i,k) *ass_d(i,k,ii,kk)
           END DO
        END DO
     END DO
     end do
     end do

     do k = 1, ncomp
     do l = 1, ncomp
        DO kk = 1, nhb_typ(k)
           DO ll = 1, nhb_typ(l)
              q_rr(k,l) = q_rr(k,l) - mx(k,kk)*nhb_no(k,kk) * mx(l,ll)*nhb_no(l,ll) * gij(k,l) *ass_d(k,l,kk,ll)
           end do
        end do
        DO i = 1, ncomp
           DO ii = 1, nhb_typ(i)
              DO j = 1, ncomp
                 DO jj = 1, nhb_typ(j)
                    q_rr(k,l) = q_rr(k,l) - 0.5 * rhoi(i) * rhoi(j) * mx(i,ii) * mx(j,jj)  &
                         * nhb_no(i,ii)*nhb_no(j,jj) *gij_rr(k,l,i,j) *ass_d(i,j,ii,jj)
                 END DO
              END DO
           END DO
        END DO
     end do
     end do

     !Ahb_rr = q_rr - q_Xr_transpose * inv( q_XX ) * q_Xr
     call MATINV( n_dim, m_dim, q_XX, q_Xr, determinant )  ! output q_Xr := inv( q_XX ) * q_Xr

     Ahb_rr = MATMUL( q_Xr_transpose, q_Xr )
     Ahb_rr = q_rr - Ahb_rr

     do k = 1, ncomp
     do l = 1, ncomp
        A_rr(k,l) = A_rr(k,l) + Ahb_rr(k,l)
     end do
     end do

     deallocate( q_XX, q_Xr, q_Xr_transpose, q_rr, Ahb_rr )

  END IF

  !-----------------------------------------------------------------------------
  ! polar terms
  !-----------------------------------------------------------------------------
  CALL A_POLAR_drhoi_drhoj ( n_comp, A_polar_rr )
  A_rr(:,:) = A_rr(:,:) + A_polar_rr(:,:)

  !-----------------------------------------------------------------------------
  ! ideal gas term
  !-----------------------------------------------------------------------------
  Aig_rr(:,:) = 0.0
  do k = 1, ncomp
     Aig_rr(k,k) = 1.0 / rhoi(k)
  end do

  deallocate( gij_r )
  deallocate( gij_rr )
  deallocate( m_r )
  deallocate( ap_r, bp_r )
  deallocate( I1_r, I2_r )
  deallocate( ord1_r, ord2_r )
  deallocate( A_polar_rr )

END SUBROUTINE ddA_drhoi_drhoj_EOS




!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! SUBROUTINE P_EOS
!
! calculates the pressure in units (Pa).
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE P_EOS

  !-----------------------------------------------------------------------------
  USE PARAMETERS, ONLY: nc, nsite
  USE EOS_VARIABLES
  USE EOS_CONSTANTS
  USE EOS_POLAR, ONLY: p_polar
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  INTEGER                                :: i, j, ii, jj, m
  INTEGER                                :: ass_cnt,max_eval
  LOGICAL                                :: assoc
  REAL                                   :: z0, z1, z2, z3
  REAL                                   :: ome, ome2, ome3, ome4, ome5, z3_m
  REAL                                   :: m_mean
  REAL                                   :: zges, zgesdz, zgesd2, zgesd3
  REAL                                   :: zhs, zhsdz, zhsd2, zhsd3
  REAL                                   :: zhc, zhcdz, zhcd2, zhcd3
  REAL, DIMENSION(nc,nc)                 :: dgijdz, dgijd2, dgijd3, dgijd4
  REAL                                   :: zdsp, zdspdz, zdspd2, zdspd3
  REAL                                   :: c1_con, c2_con, c3_con, c4_con, c5_con
  REAL                                   :: I2, edI1dz, edI2dz, edI1d2, edI2d2
  REAL                                   :: edI1d3, edI2d3, edI1d4, edI2d4
  REAL                                   :: zhb, zhbdz, zhbd2, zhbd3
  REAL, DIMENSION(nc,nc,nsite,nsite)     :: delta, dq_dz, dq_d2, dq_d3, dq_d4
  REAL, DIMENSION(nc,nsite)              :: mx_itr, dmx_dz, ndmxdz, dmx_d2, ndmxd2
  REAL, DIMENSION(nc,nsite)              :: dmx_d3, ndmxd3, dmx_d4, ndmxd4
  REAL                                   :: err_sum, sum0, sum1, sum2, sum3, sum4, attenu, tol
  REAL                                   :: sum_d1, sum_d2, sum_d3, sum_d4
  REAL                                   :: zdd, zddz, zddz2, zddz3
  REAL                                   :: zqq, zqqz, zqqz2, zqqz3
  REAL                                   :: zdq, zdqz, zdqz2, zdqz3
  !-----------------------------------------------------------------------------


  !-----------------------------------------------------------------------------
  ! abbreviations
  !-----------------------------------------------------------------------------
  rho = eta/z3t
  z0 = z0t*rho
  z1 = z1t*rho
  z2 = z2t*rho
  z3 = z3t*rho

  m_mean = z0t/(PI/6.0)
  ome    = 1.0 -eta
  ome2 = ome * ome
  ome3 = ome2 * ome
  ome4 = ome2 * ome2
  ome5 = ome4 * ome

  ! m_mean2=0.0
  ! lij(1,2)= -0.050
  ! lij(2,1)=lij(1,2)
  ! DO i =1,ncomp
  !   DO j =1,ncomp
  !     m_mean2=m_mean2+x(i)*x(j) * (mseg(i)+mseg(j))/2.0*(1.0-lij(i,j))
  !   ENDDO
  ! ENDDO


  !-----------------------------------------------------------------------------
  ! radial distr. function at contact,  gij , and derivatives
  ! dgijdz=d(gij)/d(eta)   and   dgijd2 = dd(gij)/d(eta)**2
  !-----------------------------------------------------------------------------
  DO  i = 1, ncomp
     DO  j=1,ncomp
        ! j=i
        gij(i,j) = 1.0/ome + 3.0*dij_ab(i,j)*z2/ome2 + 2.0*(dij_ab(i,j)*z2)**2 /ome3
        dgijdz(i,j)= 1.0/ome2 + 3.0*dij_ab(i,j)*z2*(1.0+z3)/z3/ome3   &
             + (dij_ab(i,j)*z2/ome2)**2 *(4.0+2.0*z3)/z3
        dgijd2(i,j) = 2.0/ome3 + 6.0*dij_ab(i,j)*z2/z3/ome4 *(2.0+z3)  &
             + (2.0*dij_ab(i,j)*z2/z3)**2 /ome5  *(1.0+4.0*z3+z3*z3)
        dgijd3(i,j) = 6.0/ome4 + 18.0*dij_ab(i,j)*z2/z3/ome5 *(3.0+z3)  &
             + 12.0*(dij_ab(i,j)*z2/z3/ome3 )**2  *(3.0+6.0*z3+z3*z3)
        dgijd4(i,j) = 24.0/ome5 + 72.0*dij_ab(i,j)*z2/z3/ome**6 *(4.0+z3)  &
             + 48.0*(dij_ab(i,j)*z2/z3)**2 /ome**7  *(6.0+8.0*z3+z3*z3)
     END DO
  END DO


  !-----------------------------------------------------------------------------
  ! p : hard sphere contribution
  !-----------------------------------------------------------------------------
  zhs   = m_mean* ( z3/ome + 3.0*z1*z2/z0/ome2 + z2**3 /z0*(3.0-z3)/ome3 )
  zhsdz = m_mean*(  1.0/ome2 + 3.0*z1*z2/z0/z3*(1.0+z3)/ome3   &
       + 6.0*z2**3 /z0/z3/ome4  )
  zhsd2 = m_mean*(  2.0/ome3  + 6.0*z1*z2/z0/z3*(2.0+z3)/ome4   &
       + 6.0*z2**3 /z0/z3/z3*(1.0+3.0*z3)/ome5  )
  zhsd3 = m_mean*(  6.0/ome4  + 18.0*z1*z2/z0/z3*(3.0+z3)/ome5   &
       + 24.0*z2**3 /z0/z3/z3*(2.0+3.0*z3)/ome**6  )


  !-----------------------------------------------------------------------------
  ! p : chain term
  !-----------------------------------------------------------------------------
  zhc   = 0.0
  zhcdz = 0.0
  zhcd2 = 0.0
  zhcd3 = 0.0
  DO i= 1, ncomp
     zhc = zhc + x(i)*(1.0-mseg(i))*eta/gij(i,i)* dgijdz(i,i)
     zhcdz = zhcdz + x(i)*(1.0-mseg(i)) *(-eta*(dgijdz(i,i)/gij(i,i))**2   &
          + dgijdz(i,i)/gij(i,i) + eta/gij(i,i)*dgijd2(i,i))
     zhcd2 = zhcd2 + x(i)*(1.0-mseg(i))  &
          *( 2.0*eta*(dgijdz(i,i)/gij(i,i))**3   &
          -2.0*(dgijdz(i,i)/gij(i,i))**2   &
          -3.0*eta/gij(i,i)**2 *dgijdz(i,i)*dgijd2(i,i)  &
          +2.0/gij(i,i)*dgijd2(i,i) +eta/gij(i,i)*dgijd3(i,i) )
     zhcd3 = zhcd3 + x(i)*(1.0-mseg(i)) *( 6.0*(dgijdz(i,i)/gij(i,i))**3   &
          -6.0*eta*(dgijdz(i,i)/gij(i,i))**4   &
          +12.0*eta/gij(i,i)**3 *dgijdz(i,i)**2 *dgijd2(i,i)  &
          -9.0/gij(i,i)**2 *dgijdz(i,i)*dgijd2(i,i) +3.0/gij(i,i)*dgijd3(i,i)  &
          -3.0*eta*(dgijd2(i,i)/gij(i,i))**2   &
          -4.0*eta/gij(i,i)**2 *dgijdz(i,i)*dgijd3(i,i)  &
          +eta/gij(i,i)*dgijd4(i,i) )
  END DO

  !-----------------------------------------------------------------------------
  ! p : PC-SAFT dispersion contribution
  !     note: edI1dz is equal to d(eta*I1)/d(eta), analogous for edI2dz
  !-----------------------------------------------------------------------------
  I2     = 0.0
  edI1dz = 0.0
  edI2dz = 0.0
  edI1d2 = 0.0
  edI2d2 = 0.0
  edI1d3 = 0.0
  edI2d3 = 0.0
  edI1d4 = 0.0
  edI2d4 = 0.0
  DO  m = 0, 6
     z3_m = z3**m
     I2    = I2 + bpar(m) * z3_m
     edI1dz= edI1dz + apar(m) * REAL(m+1) * z3_m
     edI2dz= edI2dz + bpar(m) * REAL(m+1) * z3_m
     edI1d2= edI1d2 + apar(m) * REAL((m+1)*m) * z3**(m-1)
     edI2d2= edI2d2 + bpar(m) * REAL((m+1)*m) * z3**(m-1)
     edI1d3= edI1d3 + apar(m) * REAL((m+1)*m*(m-1)) * z3**(m-2)
     edI2d3= edI2d3 + bpar(m) * REAL((m+1)*m*(m-1)) * z3**(m-2)
     edI1d4= edI1d4 + apar(m) * REAL((m+1)*m*(m-1)*(m-2)) * z3**(m-3)
     edI2d4= edI2d4 + bpar(m) * REAL((m+1)*m*(m-1)*(m-2)) * z3**(m-3)
  END DO

  c1_con= 1.0/ (  1.0 + m_mean*(8.0*eta-2.0*eta**2 )/ome4   &
       + (1.0 - m_mean)*(20.0*eta-27.0*eta**2   &
       + 12.0*eta**3 -2.0*eta**4 ) /(ome*(2.0-eta))**2   )
  c2_con= - c1_con*c1_con  &
       *(m_mean*(-4.0*eta**2 +20.0*eta+8.0)/ome5  + (1.0 - m_mean)  &
       *(2.0*eta**3 +12.0*eta**2 -48.0*eta+40.0)  &
       /(ome*(2.0-eta))**3  )
  c3_con= 2.0 * c2_con*c2_con/c1_con - c1_con*c1_con  &
       *( m_mean*(-12.0*eta**2 +72.0*eta+60.0)/ome**6   &
       + (1.0 - m_mean)  &
       *(-6.0*eta**4 -48.0*eta**3 +288.0*eta**2   &
       -480.0*eta+264.0) /(ome*(2.0-eta))**4  )
  c4_con= 6.0*c2_con*c3_con/c1_con -6.0*c2_con**3 /c1_con**2   &
       - c1_con*c1_con  &
       *( m_mean*(-48.0*eta**2 +336.0*eta+432.0)/ome**7   &
       + (1.0 - m_mean)  &
       *(24.0*eta**5 +240.0*eta**4 -1920.0*eta**3   &
       +4800.0*eta**2 -5280.0*eta+2208.0) /(ome*(2.0-eta))**5  )
  c5_con= 6.0*c3_con**2 /c1_con - 36.0*c2_con**2 /c1_con**2 *c3_con  &
       + 8.0*c2_con/c1_con*c4_con+24.0*c2_con**4 /c1_con**3   &
       - c1_con*c1_con  &
       *( m_mean*(-240.0*eta**2 +1920.0*eta+3360.0)/ome**8   &
       + (1.0 - m_mean)  &
       *(-120.0*eta**6 -1440.0*eta**5 +14400.0*eta**4   &
       -48000.0*eta**3 +79200.0*eta**2  -66240.0*eta+22560.0)  &
       /(ome*(2.0-eta))**6  )

  zdsp  = - 2.0*PI*rho*edI1dz*order1  &
       - PI*rho*order2*m_mean*(c2_con*I2*eta + c1_con*edI2dz)
  zdspdz= zdsp/eta - 2.0*PI*rho*edI1d2*order1  &
       - PI*rho*order2*m_mean*(c3_con*I2*eta + 2.0*c2_con*edI2dz + c1_con*edI2d2)
  zdspd2= -2.0*zdsp/eta/eta +2.0*zdspdz/eta  &
       - 2.0*PI*rho*edI1d3*order1 - PI*rho*order2*m_mean*(c4_con*I2*eta  &
       + 3.0*c3_con*edI2dz +3.0*c2_con*edI2d2 +c1_con*edI2d3)
  zdspd3= 6.0*zdsp/eta**3  -6.0*zdspdz/eta/eta  &
       + 3.0*zdspd2/eta - 2.0*PI*rho*edI1d4*order1  &
       - PI*rho*order2*m_mean*(c5_con*I2*eta  &
       + 4.0*c4_con*edI2dz +6.0*c3_con*edI2d2  &
       + 4.0*c2_con*edI2d3 + c1_con*edI2d4)



  !-----------------------------------------------------------------------------
  ! p: TPT-1-association accord. to Chapman et al.
  !-----------------------------------------------------------------------------
  zhb   = 0.0
  zhbdz = 0.0
  zhbd2 = 0.0
  zhbd3 = 0.0
  assoc = .false.
  DO i = 1,ncomp
     IF ( nhb_typ(i) /= 0 ) assoc = .true.
  END DO
  IF (assoc) THEN

     DO i = 1, ncomp
        DO ii = 1, nhb_typ(i)
           DO j = 1, ncomp
              DO jj = 1, nhb_typ(j)
                 delta(i,j,ii,jj) = gij(i,j)    * ass_d(i,j,ii,jj)
                 dq_dz(i,j,ii,jj) = dgijdz(i,j) * ass_d(i,j,ii,jj)
                 dq_d2(i,j,ii,jj) = dgijd2(i,j) * ass_d(i,j,ii,jj)
                 dq_d3(i,j,ii,jj) = dgijd3(i,j) * ass_d(i,j,ii,jj)
                 dq_d4(i,j,ii,jj) = dgijd4(i,j) * ass_d(i,j,ii,jj)
              END DO
           END DO
        END DO
     END DO

     ! --- constants for iteration ---------------------------------------------
     attenu = 0.7
     tol = 1.E-10
     IF ( eta < 0.2  ) tol = 1.E-12
     IF ( eta < 0.01 ) tol = 1.E-13
     IF ( eta < 1.E-6) tol = 1.E-15
     max_eval = 1000

     ! --- initialize mx(i,j) --------------------------------------------------
     DO i = 1, ncomp
        DO ii = 1, nhb_typ(i)
           mx(i,ii) = 1.0
           dmx_dz(i,ii) = 0.0
           dmx_d2(i,ii) = 0.0
           dmx_d3(i,ii) = 0.0
           dmx_d4(i,ii) = 0.0
        END DO
     END DO

     ! --- iterate over all components and all sites ---------------------------
     ass_cnt = 0
     err_sum = tol + 1.0
     DO WHILE ( err_sum > tol .AND. ass_cnt <= max_eval)
        ass_cnt = ass_cnt + 1
        DO i = 1, ncomp
           DO ii = 1, nhb_typ(i)
              sum0 = 0.0
              sum1 = 0.0
              sum2 = 0.0
              sum3 = 0.0
              sum4 = 0.0
              DO j = 1, ncomp
                 DO jj = 1, nhb_typ(j)
                    sum0 =sum0 +x(j)*nhb_no(j,jj)*     mx(j,jj)* delta(i,j,ii,jj)
                    sum1 =sum1 +x(j)*nhb_no(j,jj)*(    mx(j,jj)* dq_dz(i,j,ii,jj)  &
                         +      dmx_dz(j,jj)* delta(i,j,ii,jj))
                    sum2 =sum2 +x(j)*nhb_no(j,jj)*(    mx(j,jj)* dq_d2(i,j,ii,jj)  &
                         + 2.0*dmx_dz(j,jj)* dq_dz(i,j,ii,jj)  &
                         +      dmx_d2(j,jj)* delta(i,j,ii,jj))
                    sum3 =sum3 +x(j)*nhb_no(j,jj)*(    mx(j,jj)* dq_d3(i,j,ii,jj)  &
                         + 3.0*dmx_dz(j,jj)* dq_d2(i,j,ii,jj)  &
                         + 3.0*dmx_d2(j,jj)* dq_dz(i,j,ii,jj)  &
                         +      dmx_d3(j,jj)* delta(i,j,ii,jj))
                    sum4 =sum4 + x(j)*nhb_no(j,jj)*(   mx(j,jj)* dq_d4(i,j,ii,jj)  &
                         + 4.0*dmx_dz(j,jj)* dq_d3(i,j,ii,jj)  &
                         + 6.0*dmx_d2(j,jj)* dq_d2(i,j,ii,jj)  &
                         + 4.0*dmx_d3(j,jj)* dq_dz(i,j,ii,jj)  &
                         +      dmx_d4(j,jj)* delta(i,j,ii,jj))
                 END DO
              END DO
              mx_itr(i,ii)= 1.0 / (1.0 + sum0 * rho)
              ndmxdz(i,ii)= -(mx_itr(i,ii)*mx_itr(i,ii))* (sum0/z3t +sum1*rho)
              ndmxd2(i,ii)= + 2.0/mx_itr(i,ii)*ndmxdz(i,ii)*ndmxdz(i,ii)  &
                   - (mx_itr(i,ii)*mx_itr(i,ii)) * (2.0/z3t*sum1 + rho*sum2)
              ndmxd3(i,ii)= - 6.0/mx_itr(i,ii)**2 *ndmxdz(i,ii)**3   &
                   + 6.0/mx_itr(i,ii)*ndmxdz(i,ii)*ndmxd2(i,ii) - mx_itr(i,ii)*mx_itr(i,ii)  &
                   * (3.0/z3t*sum2 + rho*sum3)
              ndmxd4(i,ii)= 24.0/mx_itr(i,ii)**3 *ndmxdz(i,ii)**4   &
                   -36.0/mx_itr(i,ii)**2 *ndmxdz(i,ii)**2 *ndmxd2(i,ii)  &
                   +6.0/mx_itr(i,ii)*ndmxd2(i,ii)**2   &
                   +8.0/mx_itr(i,ii)*ndmxdz(i,ii)*ndmxd3(i,ii) - mx_itr(i,ii)**2   &
                   *(4.0/z3t*sum3 + rho*sum4)
           END DO
        END DO

        err_sum = 0.0
        DO i = 1, ncomp
           DO ii = 1, nhb_typ(i)
              err_sum = err_sum + ABS(mx_itr(i,ii) - mx(i,ii))  &
                   + ABS(ndmxdz(i,ii) - dmx_dz(i,ii)) + ABS(ndmxd2(i,ii) - dmx_d2(i,ii))
              mx(i,ii)     = mx_itr(i,ii)*attenu +     mx(i,ii) * (1.0-attenu)
              dmx_dz(i,ii) = ndmxdz(i,ii)*attenu + dmx_dz(i,ii) * (1.0-attenu)
              dmx_d2(i,ii) = ndmxd2(i,ii)*attenu + dmx_d2(i,ii) * (1.0-attenu)
              dmx_d3(i,ii) = ndmxd3(i,ii)*attenu + dmx_d3(i,ii) * (1.0-attenu)
              dmx_d4(i,ii) = ndmxd4(i,ii)*attenu + dmx_d4(i,ii) * (1.0-attenu)
           END DO
        END DO
     END DO

     IF ( ass_cnt >= max_eval .AND. err_sum > SQRT(tol) ) THEN
        WRITE (*,'(a,2G15.7)') 'P_EOS: Max_eval violated (mx) Err_Sum= ',err_sum,tol
        ! stop
     END IF


     ! --- calculate the hydrogen-bonding contribution -------------------------
     DO i = 1, ncomp
        sum_d1 = 0.0
        sum_d2 = 0.0
        sum_d3 = 0.0
        sum_d4 = 0.0
        DO ii = 1, nhb_typ(i)
           sum_d1= sum_d1 +nhb_no(i,ii)* dmx_dz(i,ii)*(1.0/mx(i,ii)-0.5)
           sum_d2= sum_d2 +nhb_no(i,ii)*(dmx_d2(i,ii)*(1.0/mx(i,ii)-0.5)  &
                -(dmx_dz(i,ii)/mx(i,ii))**2 )
           sum_d3= sum_d3 +nhb_no(i,ii)*(dmx_d3(i,ii)*(1.0/mx(i,ii)-0.5)  &
                -3.0/mx(i,ii)**2 *dmx_dz(i,ii)*dmx_d2(i,ii) + 2.0*(dmx_dz(i,ii)/mx(i,ii))**3 )
           sum_d4= sum_d4 +nhb_no(i,ii)*(dmx_d4(i,ii)*(1.0/mx(i,ii)-0.5)  &
                -4.0/mx(i,ii)**2 *dmx_dz(i,ii)*dmx_d3(i,ii)  &
                + 12.0/mx(i,ii)**3 *dmx_dz(i,ii)**2 *dmx_d2(i,ii)  &
                - 3.0/mx(i,ii)**2 *dmx_d2(i,ii)**2  - 6.0*(dmx_dz(i,ii)/mx(i,ii))**4 )
        END DO
        zhb   = zhb   + x(i) * eta * sum_d1
        zhbdz = zhbdz + x(i) * eta * sum_d2
        zhbd2 = zhbd2 + x(i) * eta * sum_d3
        zhbd3 = zhbd3 + x(i) * eta * sum_d4
     END DO
     zhbdz = zhbdz + zhb/eta
     zhbd2 = zhbd2 + 2.0/eta*zhbdz-2.0/eta**2 *zhb
     zhbd3 = zhbd3 - 6.0/eta**2 *zhbdz+3.0/eta*zhbd2 + 6.0/eta**3 *zhb
  END IF


  !-----------------------------------------------------------------------------
  ! p: polar terms
  !-----------------------------------------------------------------------------
  CALL P_POLAR ( zdd, zddz, zddz2, zddz3, zqq, zqqz, zqqz2, zqqz3, zdq, zdqz, zdqz2, zdqz3 )


  !-----------------------------------------------------------------------------
  ! compressibility factor z and total p
  ! as well as derivatives d(z)/d(eta) and d(p)/d(eta) with unit [Pa]
  !-----------------------------------------------------------------------------
  zges   = 1.0 + zhs + zhc + zdsp + zhb + zdd + zqq + zdq
  zgesdz = zhsdz + zhcdz + zdspdz + zhbdz + zddz + zqqz + zdqz
  zgesd2 = zhsd2 + zhcd2 + zdspd2 + zhbd2 + zddz2 +zqqz2+zdqz2
  zgesd3 = zhsd3 + zhcd3 + zdspd3 + zhbd3 + zddz3 +zqqz3+zdqz3

  pges   =   zges  *rho *(kbol*t)/1.E-30
  pgesdz = ( zgesdz*rho + zges*rho/z3 )*(kbol*t)/1.E-30
  pgesd2 = ( zgesd2*rho + 2.0*zgesdz*rho/z3 )*(kbol*t)/1.E-30
  pgesd3 = ( zgesd3*rho + 3.0*zgesd2*rho/z3 )*(kbol*t)/1.E-30

END SUBROUTINE P_EOS




!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! SUBROUTINE F_EOS
!
! calculates the Helmholtz energy f/kT. The input to the subroutine is
! (T,eta,x), where eta is the packing fraction.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE F_EOS

  USE PARAMETERS, ONLY: nc, nsite
  USE EOS_VARIABLES
  USE EOS_CONSTANTS
  USE EOS_POLAR, ONLY: f_polar
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  INTEGER                                :: i, j, ii, jj, m
  REAL                                   :: z0, z1, z2, z3
  REAL                                   :: ome, ome2, ome3, m_mean   ! ,lij(nc,nc)
  REAL                                   :: I1, I2, c1_con
  REAL                                   :: fhs, fdsp, fhc

  LOGICAL                                :: assoc
  INTEGER                                :: ass_cnt,max_eval
  REAL                                   :: delta(nc,nc,nsite,nsite)
  REAL                                   :: mx_itr(nc,nsite), err_sum, sum, attenu, tol, fhb
  REAL                                   :: ass_s1, ass_s2

  REAL                                   :: fdd, fqq, fdq
  !-----------------------------------------------------------------------------


  !-----------------------------------------------------------------------------
  ! abbreviations
  !-----------------------------------------------------------------------------
  rho = eta/z3t
  IF ( rho /= rho ) write (*,*) 'F_EOS: error in density',eta, z3t
  z0 = z0t*rho
  z1 = z1t*rho
  z2 = z2t*rho
  z3 = z3t*rho

  m_mean = z0t / ( PI / 6.0 )
  ome    = 1.0 - eta
  ome2 = ome * ome
  ome3 = ome * ome2

  ! m_mean2  = 0.0
  ! lij(1,2) = -0.05
  ! lij(2,1) = lij(1,2)
  ! DO i = 1, ncomp
  !    DO j = 1, ncomp
  !       m_mean2 = m_mean2 + x(i)*x(j)*(mseg(i)+mseg(j))/2.0*(1.0-lij(i,j))
  !    ENDDO
  ! ENDDO


  !-----------------------------------------------------------------------------
  ! radial distr. function at contact,  gij
  !-----------------------------------------------------------------------------
  DO  i = 1, ncomp
     DO  j=1,ncomp
        gij(i,j) = 1.0/ome + 3.0*dij_ab(i,j)*z2/ome2 + 2.0*(dij_ab(i,j)*z2)**2 /ome3
     END DO
  END DO


  !-----------------------------------------------------------------------------
  ! Helmholtz energy : hard sphere contribution
  !-----------------------------------------------------------------------------
  fhs= m_mean*(  3.0*z1*z2/ome + z2**3 /z3/ome2 + (z2**3 /z3/z3-z0)*LOG(ome)  )/z0


  !-----------------------------------------------------------------------------
  ! Helmholtz energy : chain term
  !-----------------------------------------------------------------------------
  fhc = 0.0
  DO i = 1, ncomp
     fhc = fhc + x(i) *(1.0- mseg(i)) *LOG(gij(i,i))
  END DO


  !-----------------------------------------------------------------------------
  ! Helmholtz energy : PC-SAFT dispersion contribution
  !-----------------------------------------------------------------------------

  I1 = 0.0
  I2 = 0.0
  DO m = 0, 6
     I1 = I1 + apar(m) * eta**m
     I2 = I2 + bpar(m) * eta**m
  END DO

  c1_con= 1.0/ (  1.0 + m_mean*(8.0*eta-2.0*eta**2 )/ome**4   &
       + (1.0 - m_mean)*(20.0*eta-27.0*eta**2 + 12.0*eta**3 -2.0*eta**4 ) /(ome*(2.0-eta))**2   )

  fdsp  = -2.0*PI * rho * I1 * order1 - PI * rho * c1_con * m_mean * I2 * order2



  !-----------------------------------------------------------------------------
  ! TPT-1-association according to Chapman et al.
  !-----------------------------------------------------------------------------
  fhb = 0.0
  assoc = .false.
  DO i = 1, ncomp
     IF (nhb_typ(i) /= 0) assoc = .true.
  END DO
  IF (assoc) THEN

     DO i = 1, ncomp
        DO ii = 1, nhb_typ(i)
           IF (mx(i,ii) == 0.0) mx(i,ii) = 1.0        !  Initialize mx(i,j)
           DO j = 1, ncomp
              DO jj = 1, nhb_typ(j)
                 delta(i,j,ii,jj) = gij(i,j) * ass_d(i,j,ii,jj)
              END DO
           END DO
        END DO
     END DO


     ! --- constants for iteration ---------------------------------------------
     attenu = 0.70
     tol = 1.E-10
     IF (eta < 0.2)  tol = 1.E-12
     IF (eta < 0.01) tol = 1.E-13
     max_eval = 200
     err_sum = 2.0 * tol

     ! --- iterate over all components and all sites ---------------------------
     ass_cnt = 0
     DO WHILE ( err_sum > tol .AND. ass_cnt <= max_eval )

        ass_cnt = ass_cnt + 1

        DO i = 1, ncomp
           DO ii = 1, nhb_typ(i)
              sum = 0.0
              DO j = 1, ncomp
                 DO jj = 1, nhb_typ(j)
                    sum = sum +  x(j)* mx(j,jj)*nhb_no(j,jj) *delta(i,j,ii,jj)
                    !            if (ass_cnt == 1) write (*,*) j,jj,x(j), mx(j,jj)
                 END DO
              END DO
              mx_itr(i,ii) = 1.0 / (1.0 + sum * rho)
              !        if (ass_cnt == 1) write (*,*) 'B',ass_cnt,sum, rho
           END DO
        END DO

        err_sum = 0.0
        DO i = 1, ncomp
           DO ii = 1, nhb_typ(i)
              err_sum = err_sum + ABS(mx_itr(i,ii) - mx(i,ii))    ! / ABS(mx_itr(i,ii))
              mx(i,ii) = mx_itr(i,ii) * attenu + mx(i,ii) * (1.0 - attenu)
           END DO
        END DO

     END DO

     IF ( err_sum /= err_sum ) write (*,*) 'F_EOS: association "not a number"',ass_cnt, rho, sum
     IF ( ass_cnt >= max_eval ) THEN
        WRITE(*,'(a,2G15.7)') 'F_EOS: Max_eval violated (mx) Err_Sum = ',err_sum,tol
        stop
     END IF


     DO i = 1, ncomp
        ass_s1  = 0.0
        ass_s2  = 0.0
        DO ii = 1, nhb_typ(i)
           ass_s1  = ass_s1  + nhb_no(i,ii) * ( 1.0 - mx(i,ii) )
           ass_s2  = ass_s2  + nhb_no(i,ii) * LOG( mx(i,ii) )
        END DO
        fhb = fhb + x(i) * ( ass_s2 + ass_s1 / 2.0 )
     END DO

  END IF


  !-----------------------------------------------------------------------------
  ! polar terms
  !-----------------------------------------------------------------------------
  CALL F_POLAR ( fdd, fqq, fdq )


  !-----------------------------------------------------------------------------
  ! resid. Helmholtz energy f/kT
  !-----------------------------------------------------------------------------
  fres = fhs + fhc + fdsp + fhb + fdd + fqq + fdq

  tfr= fres

END SUBROUTINE F_EOS



!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! SUBROUTINE PERTURBATION_PARAMETER
!
! calculates density-independent parameters of the equation of state.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE PERTURBATION_PARAMETER

  USE PARAMETERS, ONLY: PI, KBOL, RGAS, NAV, TAU
  USE EOS_VARIABLES
  USE EOS_CONSTANTS
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  INTEGER                                :: i, j, k, l, m, no
  LOGICAL                                :: assoc, qudpole, dipole
  REAL                                   :: m_mean
  REAL, DIMENSION(nc)                    :: d00, u
  REAL, DIMENSION(nc,nc,nsite,nsite)     :: eps_hb
  REAL, DIMENSION(nc,nc)                 :: kap_hb
  REAL                                   :: eps_kij, k_kij
  !-----------------------------------------------------------------------------

  !-----------------------------------------------------------------------------
  ! pure component parameters
  !-----------------------------------------------------------------------------
  DO  i = 1, ncomp
     u(i)   = parame(i,3)
     mseg(i)= parame(i,1)
     dhs(i) = parame(i,2) * ( 1.0 - 0.12 * EXP( -3.0 * parame(i,3) / t ) )
     d00(i) = parame(i,2)
  END DO


  !-----------------------------------------------------------------------------
  ! combination rules
  !-----------------------------------------------------------------------------
  DO  i = 1, ncomp
     DO  j = 1, ncomp
        sig_ij(i,j) = 0.5 * ( d00(i) + d00(j) )
        uij(i,j) = ( 1.0 - kij(i,j) ) * ( u(i)*u(j) )**0.5
     END DO
  END DO


  !-----------------------------------------------------------------------------
  ! abbreviations
  !-----------------------------------------------------------------------------
  z0t = PI / 6.0 * SUM( x(1:ncomp) * mseg(1:ncomp) )
  z1t = PI / 6.0 * SUM( x(1:ncomp) * mseg(1:ncomp) * dhs(1:ncomp) )
  z2t = PI / 6.0 * SUM( x(1:ncomp) * mseg(1:ncomp) * dhs(1:ncomp)**2 )
  z3t = PI / 6.0 * SUM( x(1:ncomp) * mseg(1:ncomp) * dhs(1:ncomp)**3 )

  m_mean = z0t / ( PI / 6.0 )

  DO i = 1, ncomp
     DO j = 1, ncomp
        dij_ab(i,j) = dhs(i)*dhs(j) / ( dhs(i) + dhs(j) )
     END DO
  END DO

  !-----------------------------------------------------------------------------
  ! dispersion term parameters for chain molecules
  !-----------------------------------------------------------------------------
  DO m = 0, 6
     apar(m) = ap(m,1) + (1.0-1.0/m_mean)*ap(m,2) + (1.0-1.0/m_mean)*(1.0-2.0/m_mean)*ap(m,3)
     bpar(m) = bp(m,1) + (1.0-1.0/m_mean)*bp(m,2) + (1.0-1.0/m_mean)*(1.0-2.0/m_mean)*bp(m,3)
  END DO


  !-----------------------------------------------------------------------------
  ! van der Waals mixing rules for perturbation terms
  !-----------------------------------------------------------------------------
  order1 = 0.0
  order2 = 0.0
  DO i = 1, ncomp
     DO j = 1, ncomp
        order1 = order1 + x(i)*x(j)* mseg(i)*mseg(j)*sig_ij(i,j)**3 * uij(i,j)/t
        order2 = order2 + x(i)*x(j)* mseg(i)*mseg(j)*sig_ij(i,j)**3 * (uij(i,j)/t)**2
     END DO
  END DO


  !-----------------------------------------------------------------------------
  ! association and polar parameters
  !-----------------------------------------------------------------------------
  assoc   = .false.
  qudpole = .false.
  dipole  = .false.
  DO i = 1, ncomp
     IF (NINT(parame(i,12)) /= 0) assoc  = .true.
     IF (parame(i,7) /= 0.0)     qudpole = .true.
     IF (parame(i,6) /= 0.0)     dipole  = .true.
  END DO

  ! --- dipole and quadrupole constants ----------------------------------------
  IF (qudpole) CALL qq_const ( qqp2, qqp3, qqp4 )
  IF (dipole)  CALL dd_const ( ddp2, ddp3, ddp4 )
  IF (dipole .AND. qudpole) CALL dq_const ( dqp2, dqp3, dqp4 )


  ! --- TPT-1-association parameters -------------------------------------------
  IF (assoc) THEN

     eps_kij = 0.0
     k_kij   = 0.0

     DO i = 1, ncomp
        IF (NINT(parame(i,12)) /= 0) THEN
           nhb_typ(i)  = NINT(parame(i,12))
           kap_hb(i,i) = parame(i,13)
           no = 0
           DO j = 1, nhb_typ(i)
              DO k = 1, nhb_typ(i)
                 eps_hb(i,i,j,k) = parame(i,(14+no))
                 no=no+1
              END DO
           END DO
           DO j = 1, nhb_typ(i)
              nhb_no(i,j) = parame(i,(14+no))
              no=no+1
           END DO
        ELSE
           nhb_typ(i) = 0
           kap_hb(i,i)= 0.0
           DO k = 1, nsite
              DO l = 1, nsite
                 eps_hb(i,i,k,l) = 0.0
              END DO
           END DO
        END IF
     END DO

     DO i = 1, ncomp
        DO j = 1, ncomp
           IF (i /= j .AND. (nhb_typ(i) /= 0 .AND. nhb_typ(j) /= 0)) THEN
              kap_hb(i,j)= (kap_hb(i,i)*kap_hb(j,j))**0.5  &
                   *((parame(i,2)*parame(j,2))**3 )**0.5  &
                   /(0.5*(parame(i,2)+parame(j,2)))**3
              kap_hb(i,j)= kap_hb(i,j)*(1.0-k_kij)
              DO k = 1, nhb_typ(i)
                 DO l = 1, nhb_typ(j)
                    IF (k /= l) THEN
                       eps_hb(i,j,k,l) = (eps_hb(i,i,k,l)+eps_hb(j,j,l,k))/2.0
                       eps_hb(i,j,k,l) = eps_hb(i,j,k,l)*(1.0-eps_kij)
                    END IF
                 END DO
              END DO
           END IF
        END DO
     END DO
     IF (nhb_typ(1) == 3) THEN
        !        write(*,*)'eps_hb manuell eingegeben'
        eps_hb(1,2,3,1) = 0.5*(eps_hb(1,1,3,1)+eps_hb(2,2,1,2))
        eps_hb(2,1,1,3) = eps_hb(1,2,3,1)
     END IF
     IF (nhb_typ(2) == 3) THEN
        eps_hb(2,1,3,1) = 0.5*(eps_hb(2,2,3,1)+eps_hb(1,1,1,2))
        eps_hb(1,2,1,3) = eps_hb(2,1,3,1)
     END IF

     DO i = 1, ncomp
        DO k = 1, nhb_typ(i)
           DO j = 1, ncomp
              DO l = 1, nhb_typ(j)
                 ass_d(i,j,k,l) = kap_hb(i,j) *sig_ij(i,j)**3 *(EXP(eps_hb(i,j,k,l)/t)-1.0)
              END DO
           END DO
        END DO
     END DO

  END IF

END SUBROUTINE PERTURBATION_PARAMETER


!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! SUBROUTINE DENSITY_ITERATION
!
! iterates the density until the calculated pressure 'pges' is equal to
! the specified pressure 'p'. A Newton-scheme is used for determining
! the root to the objective function  f(eta) = (pges / p ) - 1.0.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE DENSITY_ITERATION

  USE EOS_VARIABLES
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  INTEGER                                :: i, start, max_i
  REAL                                   :: eta_iteration
  REAL                                   :: error, dydx, acc_i, delta_eta
  !-----------------------------------------------------------------------------


  IF ( densav(phas) /= 0.0 .AND. eta_start == denold(phas) ) THEN
     denold(phas) = eta_start
     eta_start = densav(phas)
  ELSE
     denold(phas) = eta_start
     densav(phas) = eta_start
  END IF


  acc_i = 1.E-9
  max_i = 30
  density_error(:) = 0.0

  i = 0
  eta_iteration = eta_start

  !-----------------------------------------------------------------------------
  ! iterate density until p_calc = p
  !-----------------------------------------------------------------------------
  iterate_density: DO

     i = i + 1
     eta = eta_iteration

     CALL p_eos_interface

     error = (pges / p ) - 1.0

     !--------------------------------------------------------------------------
     ! correction for instable region
     !--------------------------------------------------------------------------
     IF ( pgesdz < 0.0 .AND. i < max_i ) THEN
        IF ( error > 0.0 .AND. pgesd2 > 0.0 ) THEN                           ! no liquid density
           CALL PRESSURE_SPINODAL
           eta_iteration = eta
           error  = (pges / p ) - 1.0
           IF ( ((pges/p ) -1.0) > 0.0 ) eta_iteration = 0.001                ! no solution possible
           IF ( ((pges/p ) -1.0) <=0.0 ) eta_iteration = eta_iteration * 1.1  ! no solution found so far
        ELSE IF ( error < 0.0 .AND. pgesd2 < 0.0 ) THEN                      ! no vapor density
           CALL PRESSURE_SPINODAL
           eta_iteration = eta
           error  = (pges / p ) - 1.0
           IF ( ((pges/p ) -1.0) < 0.0 ) eta_iteration = 0.5                  ! no solution possible
           IF ( ((pges/p ) -1.0) >=0.0 ) eta_iteration = eta_iteration * 0.9  ! no solution found so far
        ELSE
           eta_iteration = (eta_iteration + eta_start) / 2.0
           IF (eta_iteration == eta_start) eta_iteration = eta_iteration + 0.2
        END IF
        CYCLE iterate_density
     END IF


     dydx = pgesdz/p
     delta_eta = error/ dydx
     IF ( delta_eta >  0.05 ) delta_eta = 0.05
     IF ( delta_eta < -0.05 ) delta_eta = -0.05

     eta_iteration   = eta_iteration - delta_eta

     IF (eta_iteration > 0.9)  eta_iteration = 0.6
     IF (eta_iteration <= 0.0) eta_iteration = 1.E-16
     start = 1

     IF ( ABS(error*p/pgesdz) < 1.E-12 ) start = 0
     IF ( ABS(error) < acc_i ) start = 0
     IF ( i > max_i ) THEN
        start = 0
        density_error(phas) = ABS( error )
        ! write (*,*) 'density iteration failed'
     END IF

     IF (start /= 1) EXIT iterate_density

  END DO iterate_density

  eta = eta_iteration

  IF ((eta > 0.3 .AND. densav(phas) > 0.3) .OR.  &
       (eta < 0.1 .AND. densav(phas) < 0.1)) densav(phas) = eta

END SUBROUTINE DENSITY_ITERATION


!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
! SUBROUTINE PRESSURE_SPINODAL
!
! iterates the density until the derivative of pressure 'pges' to
! density is equal to zero. A Newton-scheme is used for determining
! the root to the objective function.
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE PRESSURE_SPINODAL

  USE EOS_VARIABLES
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  INTEGER                                :: i, max_i
  REAL                                   :: eta_iteration
  REAL                                   :: error, acc_i, delta_eta
  !-----------------------------------------------------------------------------

  acc_i = 1.E-6
  max_i = 30

  i = 0
  eta_iteration = eta_start

  !-----------------------------------------------------------------------------
  ! iterate density until p_calc = p
  !-----------------------------------------------------------------------------

  error = acc_i + 1.0
  DO WHILE ( ABS(error) > acc_i .AND. i < max_i )

     i = i + 1
     eta = eta_iteration

     CALL p_eos_interface

     error = pgesdz

     delta_eta = error/ pgesd2
     IF ( delta_eta >  0.02 ) delta_eta = 0.02
     IF ( delta_eta < -0.02 ) delta_eta = -0.02

     eta_iteration   = eta_iteration - delta_eta
     ! write (*,'(a,i3,3G18.10)') 'iter',i, error, eta_iteration, pgesdz

     IF (eta_iteration > 0.9)  eta_iteration = 0.5
     IF (eta_iteration <= 0.0) eta_iteration = 1.E-16

  END DO

  eta = eta_iteration

END SUBROUTINE PRESSURE_SPINODAL


!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
!
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE p_dz

  USE PARAMETERS, ONLY: nc, nsite
  USE EOS_VARIABLES
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  REAL                                   :: eta_0, dist, fact
  REAL                                   :: fres1, fres2, fres3, fres4, fres5
  REAL                                   :: df_dr, df_dr2, df_dr3, df_dr4
  !-----------------------------------------------------------------------------


  IF (eta > 1.E-1) THEN
     fact = 1.0
  ELSE IF (eta <= 1.E-1 .AND. eta > 1.E-2) THEN
     fact = 10.0
  ELSE
     fact = 100.0
  END IF
  dist = eta * 5.E-4 * fact
  ! dist = eta * 4.E-3 * fact


  eta_0  = eta
  eta  = eta_0 - 2.0*dist
  CALL P_EOS
  fres1  = pges
  eta  = eta_0 - dist
  CALL P_EOS
  fres2  = pges
  eta  = eta_0 + dist
  CALL P_EOS
  fres3  = pges
  eta  = eta_0 + 2.0*dist
  CALL P_EOS
  fres4  = pges
  eta  = eta_0
  CALL P_EOS
  fres5  = pges

  df_dr   = (-fres4+8.0*fres3-8.0*fres2+fres1)/(12.0*dist)
  df_dr2 = (-fres4+16.0*fres3-3.d1*fres5+16.0*fres2-fres1)  &
       /(12.0*(dist**2 ))
  df_dr3 = (fres4-2.0*fres3+2.0*fres2-fres1) /(2.0*dist**3 )
  df_dr4 = (fres4-4.0*fres3+6.0*fres5-4.0*fres2+fres1) /(1.0*dist**4 )

  WRITE (*,*) 'f`   = ',df_dr
  WRITE (*,*) 'f``  = ',df_dr2
  WRITE (*,*) 'f``` = ',df_dr3
  WRITE (*,*) 'f````= ',df_dr4,eta
  ! if (eta.gt.0.3) stop

END SUBROUTINE p_dz



!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
!
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE f_dz

  USE PARAMETERS, ONLY: nc, nsite
  USE EOS_VARIABLES
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  REAL                                   :: eta_0, dist, fact
  REAL                                   :: fres1, fres2, fres3, fres4, fres5
  REAL                                   :: df_dr, df_dr2, df_dr3, df_dr4
  !-----------------------------------------------------------------------------


  IF (eta > 1.E-1) THEN
     fact = 1.0
  ELSE IF (eta <= 1.E-1 .AND. eta > 1.E-2) THEN
     fact = 10.0
  ELSE
     fact = 100.0
  END IF
  dist = eta*5.E-4 *fact
  ! dist = eta*4.E-3 *fact

  eta_0  = eta
  eta  = eta_0 - 2.0*dist
  CALL F_EOS
  fres1  = tfr
  eta  = eta_0 - dist
  CALL F_EOS
  fres2  = tfr
  eta  = eta_0 + dist
  CALL F_EOS
  fres3  = tfr
  eta  = eta_0 + 2.0*dist
  CALL F_EOS
  fres4  = tfr
  eta  = eta_0
  CALL F_EOS
  fres5  = tfr

  df_dr   = (-fres4+8.0*fres3-8.0*fres2+fres1)/(12.0*dist)
  df_dr2 = (-fres4+16.0*fres3-3.d1*fres5+16.0*fres2-fres1)  &
       /(12.0*(dist**2 ))
  df_dr3 = (fres4-2.0*fres3+2.0*fres2-fres1) /(2.0*dist**3 )
  df_dr4 = (fres4-4.0*fres3+6.0*fres5-4.0*fres2+fres1) /(1.0*dist**4 )

  WRITE (*,*) 'f`   = ',df_dr
  WRITE (*,*) 'f``  = ',df_dr2
  WRITE (*,*) 'f``` = ',df_dr3
  WRITE (*,*) 'f````= ',df_dr4,eta
  WRITE (*,*) 'z   = ',df_dr*eta
  WRITE (*,*) 'z`  = ',df_dr2*eta + df_dr
  WRITE (*,*) 'z`` = ',df_dr3*eta + 2.0* df_dr2
  WRITE (*,*) 'z```= ',df_dr4*eta + 3.0* df_dr3 ,eta

END SUBROUTINE f_dz



!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW
!
!WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW

SUBROUTINE dfr_eos

  USE PARAMETERS, ONLY: nc, nsite
  USE EOS_VARIABLES
  IMPLICIT NONE

  !-----------------------------------------------------------------------------
  INTEGER                                :: i, k
  REAL                                   :: flsum
  REAL, DIMENSION(nc)                    :: grada, atilde2, atilde, xsav
  !-----------------------------------------------------------------------------

  rho = eta/z3t

  CALL F_EOS

  flsum = 0.0
  DO k = 1, ncomp
     flsum = flsum + LOG(rho*x(k))
  END DO
  !      flsum = flsum -LOG(p*1.E-30/(rho*kbol*t))
  DO k = 1, ncomp
     atilde(k) = fres*rho+x(k)*rho*LOG(rho*x(k))
  END DO



  DO i=1,ncomp
     xsav(i) = x(i)
     x(i) = xsav(i) + 1.E-8
     CALL F_EOS
     flsum = 0.0
     DO k = 1, ncomp
        flsum=flsum+ rho*x(k)*LOG(x(k))
     END DO
     !        flsum = flsum -LOG(p*1.E-30/(rho*kbol*t))
     DO k = 1, ncomp
        atilde2(k) = fres*rho+x(k)*rho*LOG(rho*x(k))
     END DO
     x(i) = xsav(i)

     grada(i) = (atilde2(i)-atilde(i) ) /1.E-8
     WRITE (*,*) 'grad',i,grada(i)

  END DO

END SUBROUTINE dfr_eos

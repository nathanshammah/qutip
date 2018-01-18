"""
Cythonized code for permutationally invariant Liouvillian
"""
import numpy as np
from scipy.sparse import csr_matrix, dok_matrix
from qutip import Qobj
cimport numpy as cnp
cimport cython


def num_dicke_states(N):
    """
    The number of dicke states with a modulo term taking care of ensembles
    with odd number of systems.

    Parameters
    -------
    N: int
        The number of two level systems
    Returns
    -------
    nds: int
        The number of Dicke states
    """
    if (not float(N).is_integer()):
        raise ValueError("Number of TLS should be an integer")

    if (N < 1):
        raise ValueError("Number of TLS should be non-negative")

    nds = (N / 2 + 1)**2 - (N % 2) / 4
    return int(nds)


def num_dicke_ladders(N):
    """
    Calculates the total number of Dicke ladders in the Dicke space for a
    collection of N two-level systems. It counts how many different "j" exist.
    Or the number of blocks in the block diagonal matrix.

    Parameters
    -------
    N: int
        The number of two level systems.
    Returns
    -------
    Nj: int
        The number of Dicke ladders
    """
    Nj = (N + 1) * 0.5 + (1 - np.mod(N, 2)) * 0.5
    return int(Nj)


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef list get_blocks(int N):
    """
    A list which gets the number of cumulative elements at each block
    boundary. For N = 4

    1 1 1 1 1
    1 1 1 1 1
    1 1 1 1 1
    1 1 1 1 1
    1 1 1 1 1
            1 1 1
            1 1 1
            1 1 1
                 1

    Thus, the blocks are [5, 8, 9] denoting that after the first block 5
    elements have been accounted for and so on. This function will later
    be helpful in the calculation of j, m, m' value for a given (row, col)
    index in this matrix.

    Returns
    -------
    blocks: arr
        An array with the number of cumulative elements at the boundary of
        each block
    """
    cdef int num_blocks = num_dicke_ladders(N)

    cdef list blocks
    blocks = [i * (N + 2 - i) for i in range(1, num_blocks + 1)]
    return blocks


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef float j_min(N):
    """
    Calculate the minimum value of j for given N

    Parameters
    ==========
    N: int
        Number of two level systems

    Returns
    =======
    jmin: float
        The minimum value of j for odd or even number of two
        level systems
    """
    if N % 2 == 0:
        return 0
    else:
        return 0.5


def j_vals(N):
    """
    Get the valid values of j for given N.
    """
    j = np.arange(j_min(N), N / 2 + 1, 1)
    return j


def m_vals(j):
    """
    Get all the possible values of m or $m^\prime$ for given j.
    """
    return np.arange(-j, j + 1, 1)



def get_index(N, j, m, m1, blocks):
    """
    Get the index in the density matrix for this j, m, m1 value.
    """
    _k = int(j - m1)
    _k_prime = int(j - m)

    block_number = int(N / 2 - j)

    offset = 0
    if block_number > 0:
        offset = blocks[block_number - 1]

    i = _k_prime + offset
    k = _k + offset

    return (i, k)


@cython.boundscheck(False)
@cython.wraparound(False)
cpdef list jmm1_dictionary(int N):
    """
    Get the index in the density matrix for this j, m, m1 value.
    """
    cdef long i
    cdef long k

    cdef dict jmm1_dict = {}
    cdef dict jmm1_inv = {}
    cdef dict jmm1_flat = {}
    cdef dict jmm1_flat_inv = {}
    cdef int l
    cdef int nds = num_dicke_states(N)

    cdef list blocks = get_blocks(N)

    jvalues = j_vals(N)

    for j in jvalues:
        mvalues = m_vals(j)
        for m in mvalues:
            for m1 in mvalues:
                i, k = get_index(N, j, m, m1, blocks)
                jmm1_dict[(i, k)] = (j, m, m1)
                jmm1_inv[(j, m, m1)] = (i, k)
                l = nds * i + k
                jmm1_flat[l] = (j, m, m1)
                jmm1_flat_inv[(j, m, m1)] = l

    return [jmm1_dict, jmm1_inv, jmm1_flat, jmm1_flat_inv]


@cython.boundscheck(False)
@cython.wraparound(False)
cdef class Dicke(object):
    """
    The Dicke States class.

    Parameters
    ----------
    N : int
        The number of two level systems
        default: 2

    hamiltonian : Qobj matrix
        An Hamiltonian H in the reduced basis set by `reduced_algebra()`.
        Matrix dimensions are (nds, nds), with nds = num_dicke_states.
        The hamiltonian is assumed to be with hbar = 1.
        default: H = jz_op(N)

    emission : float
        Collective spontaneous emmission coefficient
        default: 1.0

    loss : float
        Incoherent loss coefficient
        default: 0.0

    dephasing : float
        Local dephasing coefficient
        default: 0.0

    pumping : float
        Incoherent pumping coefficient
        default: 0.0

    collective_pumping : float
        Collective pumping coefficient
        default: 0.0

    collective_dephasing : float
        Collective dephasing coefficient
        default: 0.0
    nds : int
        The number of Dicke states
        default: nds(2) = 4

    dshape : tuple
        The tuple (nds, nds)
        default: (4,4)

    blocks : array
        A list which gets the number of cumulative elements at each block
        boundary
        default:  array([3, 4])
    """
    cdef int N
    cdef float loss, dephasing, pumping, emission
    cdef float collective_pumping, collective_dephasing

    def __init__(self, int N=1, float loss=0., float dephasing=0.,
                 float pumping=0., float emission=0.,
                 collective_pumping=0., collective_dephasing=0.):
        self.N = N

        self.emission = emission
        self.loss = loss
        self.dephasing = dephasing
        self.pumping = pumping
        self.collective_pumping = collective_pumping
        self.collective_dephasing = collective_dephasing

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef object lindbladian(self):
        """
        Build the Lindbladian superoperator of the dissipative dynamics as a
        sparse matrix using COO.

        Returns
        ----------
        lindblad_qobj: Qobj superoperator (sparse)
                The matrix size is (nds**2, nds**2) where nds is the number of
                Dicke states.

        """
        N = self.N
        cdef int nds = num_dicke_states(N)
        cdef int num_ladders = num_dicke_ladders(N)

        cdef list lindblad_row = []
        cdef list lindblad_col = []
        cdef list lindblad_data = []

        cdef tuple jmm1_1
        cdef tuple jmm1_2
        cdef tuple jmm1_3
        cdef tuple jmm1_4
        cdef tuple jmm1_5
        cdef tuple jmm1_6
        cdef tuple jmm1_7
        cdef tuple jmm1_8
        cdef tuple jmm1_9

        _1, _2, jmm1_row, jmm1_inv = jmm1_dictionary(N)

        # perform loop in each row of matrix
        for r in jmm1_row:
            j, m, m1 = jmm1_row[r]
            jmm1_1 = (j, m, m1)
            jmm1_2 = (j, m + 1, m1 + 1)
            jmm1_3 = (j + 1, m + 1, m1 + 1)
            jmm1_4 = (j - 1, m + 1, m1 + 1)
            jmm1_5 = (j + 1, m, m1)
            jmm1_6 = (j - 1, m, m1)
            jmm1_7 = (j + 1, m - 1, m1 - 1)
            jmm1_8 = (j, m - 1, m1 - 1)
            jmm1_9 = (j - 1, m - 1, m1 - 1)

            g1 = self.gamma1(jmm1_1)
            c1 = jmm1_inv[jmm1_1]

            lindblad_row.append(int(r))
            lindblad_col.append(int(c1))
            lindblad_data.append(g1)

            # generate gammas in the given row
            # check if the gammas exist
            # load gammas in the lindbladian in the correct position

            if jmm1_2 in jmm1_inv:
                g2 = self.gamma2(jmm1_2)
                c2 = jmm1_inv[jmm1_2]

                lindblad_row.append(int(r))
                lindblad_col.append(int(c2))
                lindblad_data.append(g2)

            if jmm1_3 in jmm1_inv:
                g3 = self.gamma3(jmm1_3)
                c3 = jmm1_inv[jmm1_3]

                lindblad_row.append(int(r))
                lindblad_col.append(int(c3))
                lindblad_data.append(g3)

            if jmm1_4 in jmm1_inv:
                g4 = self.gamma4(jmm1_4)
                c4 = jmm1_inv[jmm1_4]

                lindblad_row.append(int(r))
                lindblad_col.append(int(c4))
                lindblad_data.append(g4)

            if jmm1_5 in jmm1_inv:
                g5 = self.gamma5(jmm1_5)
                c5 = jmm1_inv[jmm1_5]

                lindblad_row.append(int(r))
                lindblad_col.append(int(c5))
                lindblad_data.append(g5)

            if jmm1_6 in jmm1_inv:
                g6 = self.gamma6(jmm1_6)
                c6 = jmm1_inv[jmm1_6]

                lindblad_row.append(int(r))
                lindblad_col.append(int(c6))
                lindblad_data.append(g6)

            if jmm1_7 in jmm1_inv:
                g7 = self.gamma7(jmm1_7)
                c7 = jmm1_inv[jmm1_7]

                lindblad_row.append(int(r))
                lindblad_col.append(int(c7))
                lindblad_data.append(g7)

            if jmm1_8 in jmm1_inv:
                g8 = self.gamma8(jmm1_8)
                c8 = jmm1_inv[jmm1_8]

                lindblad_row.append(int(r))
                lindblad_col.append(int(c8))
                lindblad_data.append(g8)

            if jmm1_9 in jmm1_inv:
                g9 = self.gamma9(jmm1_9)
                c9 = jmm1_inv[jmm1_9]

                lindblad_row.append(int(r))
                lindblad_col.append(int(c9))
                lindblad_data.append(g9)

        cdef lindblad_matrix = csr_matrix((lindblad_data, (lindblad_row, lindblad_col)),
                                          shape=(nds**2, nds**2))

        # make matrix a Qobj superoperator with expected dims
        llind_dims = [[[nds], [nds]], [[nds], [nds]]]
        cdef object lindblad_qobj = Qobj(lindblad_matrix, dims=llind_dims)

        return lindblad_qobj

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef complex gamma1(self, tuple jmm1):
        """
        Calculate gamma1 for value of j, m, m'
        """
        cdef float j, m, m1

        j, m, m1 = jmm1

        cdef float yS, yL, yD, yP, yCP, yCD

        cdef float N
        N = float(self.N)

        cdef float spontaneous, losses, pump, collective_pump
        cdef float dephase, collective_dephase, g1

        yS = self.emission
        yL = self.loss
        yD = self.dephasing
        yP = self.pumping
        yCP = self.collective_pumping
        yCD = self.collective_dephasing

        spontaneous = yS / 2 * (2 * j * (j + 1) - m * (m - 1) - m1 * (m1 - 1))
        losses = yL / 2 * (N + m + m1)
        pump = yP / 2 * (N - m - m1)
        collective_pump = yCP / 2 * \
            (2 * j * (j + 1) - m * (m + 1) - m1 * (m1 + 1))
        collective_dephase = yCD / 2 * (m - m1)**2

        if j <= 0:
            dephase = yD * N / 4
        else:
            dephase = yD / 2 * (N / 2 - m * m1 * (N / 2 + 1) / j / (j + 1))

        g1 = spontaneous + losses + pump + dephase + \
            collective_pump + collective_dephase

        return(-g1)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef complex gamma2(self, tuple jmm1):
        """
        Calculate gamma2 for given j, m, m'
        """
        cdef float j, m, m1

        j, m, m1 = jmm1

        cdef float yS, yL, yD, yP, yCP, yCD, g2

        cdef float N
        N = float(self.N)

        cdef float spontaneous, losses, pump, collective_pump
        cdef float dephase, collective_dephase

        j, m, m1 = jmm1
        yS = self.emission
        yL = self.loss

        if yS == 0:
            spontaneous = 0.0
        else:
            spontaneous = yS * \
                np.sqrt((j + m) * (j - m + 1) * (j + m1) * (j - m1 + 1))

        if (yL == 0) or (j <= 0):
            losses = 0.0
        else:
            losses = yL / 2 * \
                np.sqrt((j + m) * (j - m + 1) * (j + m1) * (j - m1 + 1)) * (N / 2 + 1) / (j * (j + 1))

        g2 = spontaneous + losses

        return (g2)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef complex gamma3(self, tuple jmm1):
        """
        Calculate gamma3 for given j, m, m'
        """
        cdef float j, m, m1
        j, m, m1 = jmm1

        cdef float yL

        cdef float N
        N = float(self.N)

        cdef float spontaneous, losses, pump, collective_pump
        cdef float dephase, collective_dephase

        cdef complex g3

        yL = self.loss

        if (yL == 0) or (j <= 0):
            g3 = 0.0
        else:
            g3 = yL / 2 * np.sqrt((j + m) * (j + m - 1) * (j + m1) * (j + m1 - 1)) * (N / 2 + j + 1) / (j * (2 * j + 1))

        return (g3)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef complex gamma4(self, tuple jmm1):
        """
        Calculate gamma4 for given j, m, m'
        """
        cdef float j, m, m1
        j, m, m1 = jmm1

        cdef float yL
        cdef float N
        N = float(self.N)

        cdef complex g4

        yL = self.loss

        if (yL == 0) or ((j + 1) <= 0):
            g4 = 0.0
        else:
            g4 = yL / 2 * np.sqrt((j - m + 1) * (j - m + 2) * (j - m1 + 1) * (j - m1 + 2)) * (N / 2 - j) / ((j + 1) * (2 * j + 1))

        return (g4)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef complex gamma5(self, tuple jmm1):
        """
        Calculate gamma5 for given j, m, m'
        """
        cdef float j, m, m1
        j, m, m1 = jmm1

        cdef float yD
        cdef float N
        N = float(self.N)

        cdef complex g5

        yD = self.dephasing

        if (yD == 0) or (j <= 0):
            g5 = 0.0
        else:
            g5 = yD / 2 * np.sqrt((j**2 - m**2) * (j**2 - m1**2)) * \
                (N / 2 + j + 1) / (j * (2 * j + 1))

        return (g5)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef complex gamma6(self, tuple jmm1):
        """
        Calculate gamma6 for given j, m, m'
        """
        cdef float j, m, m1
        j, m, m1 = jmm1

        cdef float yD
        cdef float N
        N = float(self.N)

        cdef complex g6

        yD = self.dephasing

        if yD == 0:
            g6 = 0.0
        else:
            g6 = yD / 2 * np.sqrt(((j + 1)**2 - m**2) * ((j + 1) **
                                                         2 - m1**2)) * (N / 2 - j) / ((j + 1) * (2 * j + 1))

        return (g6)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef complex gamma7(self, tuple jmm1):
        """
        Calculate gamma7 for given j, m, m'
        """
        cdef float j, m, m1
        j, m, m1 = jmm1

        cdef float yP
        cdef float N
        N = float(self.N)

        cdef complex g7

        yP = self.pumping

        if (yP == 0) or (j <= 0):
            g7 = 0.0
        else:
            g7 = yP / 2 * np.sqrt((j - m - 1) * (j - m) * (j - m1 - 1) * (j - m1)) * (N / 2 + j + 1) / (j * (2 * j + 1))

        return (g7)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef complex gamma8(self, tuple jmm1):
        """
        Calculate gamma8 for given j, m, m'
        """
        cdef float j, m, m1
        j, m, m1 = jmm1

        cdef float yP, yCP

        cdef float N
        N = float(self.N)

        cdef complex g8

        yP = self.pumping
        yCP = self.collective_pumping

        if (yP == 0) or (j <= 0):
            pump = 0.0
        else:
            pump = yP / 2 * np.sqrt((j + m + 1) * (j - m) * (j + m1 + 1) * (j - m1)) * (N / 2 + 1) / (j * (j + 1))

        if yCP == 0:
            collective_pump = 0.0
        else:
            collective_pump = yCP * \
                np.sqrt((j - m) * (j + m + 1) * (j + m1 + 1) * (j - m1))

        g8 = pump + collective_pump

        return (g8)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    cpdef complex gamma9(self, tuple jmm1):
        """
        Calculate gamma9 for given j, m, m'
        """
        cdef float j, m, m1
        j, m, m1 = jmm1

        cdef float yP
        cdef float N
        N = float(self.N)

        cdef complex g9

        yP = self.pumping

        if (yP == 0):
            g9 = 0.0
        else:
            g9 = yP / 2 * np.sqrt((j + m + 1) * (j + m + 2) * (j + m1 + 1)
                                  * (j + m1 + 2)) * (N / 2 - j) / ((j + 1) * (2 * j + 1))

        return (g9)

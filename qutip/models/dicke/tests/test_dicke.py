"""
Tests for Permutation Invariance methods
"""
import numpy as np
from numpy.testing import (assert_, run_module_suite, assert_raises,
                           assert_array_equal, assert_array_almost_equal,
                           assert_almost_equal)

from qutip.pim.dicke import (num_dicke_states, num_two_level, irreducible_dim,
                             num_dicke_ladders, generate_dicke_space, initial_dicke_state,
                             Pim, _tau_column_index)

class TestPim:
    """
    A test class for the Permutation invariance matrix generation
    """
    def test_num_dicke_states(self):
        """
        Tests the `num_dicke_state` function
        """
        N_list = [1, 2, 3, 4, 5, 6, 9, 10, 20, 100, 123]
        dicke_states = [num_dicke_states(i) for i in N_list]

        assert_array_equal(dicke_states, [2, 4, 6, 9, 12, 16, 30, 36, 121, 2601, 3906])

        N = -1
        assert_raises(ValueError, num_dicke_states, N)

        N = 0.2
        assert_raises(ValueError, num_dicke_states, N)

    def test_num_two_level(self):
        """
        Tests the `num_two_level` function.
        """
        N_dicke = [2, 4, 6, 9, 12, 16, 30, 36, 121, 2601, 3906]
        N = [1, 2, 3, 4, 5, 6, 9, 10, 20, 100, 123]

        calculated_N = [num_two_level(i) for i in N_dicke]

        assert_array_equal(calculated_N, N)
    
    def test_num_dicke_ladders(self):
        """
        Tests the `num_dicke_ladders` function
        """
        ndl_true = [1, 2, 2, 3, 3, 4, 4, 5, 5]
        ndl = [num_dicke_ladders(N) for N in range (1, 10)]        
        assert_array_equal(ndl, ndl_true)    

    def test_irreducible_dim(self):
        """
        Test the irreducible dimension function
        """
        pass

    def test_taus(self):
        """
        Tests the calculation of various Tau values for a given system

        For N = 6 |j, m> would be :

        | 3, 3>
        | 3, 2> | 2, 2>
        | 3, 1> | 2, 1> | 1, 1>
        | 3, 0> | 2, 0> | 1, 0> |0, 0>
        | 3,-1> | 2,-1> | 1,-1>
        | 3,-2> | 2,-2>
        | 3,-3>
        """
        N = 6
        emission = 1.
        loss = 1.
        dephasing = 1.
        pumping = 1.
        collective_pumping = 1.

        model = Pim(N, emission, loss, dephasing, pumping, collective_pumping)

        tau_calculated = [model.tau3(3, 1), model.tau2(2, 1), model.tau4(1, 1),
                          model.tau5(3, 0), model.tau1(2, 0), model.tau6(1, 0),
                          model.tau7(3,-1), model.tau8(2,-1), model.tau9(1,-1)]

        tau_real = [2., 8., 0.333333,
                    1.5, -19.5, 0.666667,
                    2., 8., 0.333333]

        assert_array_almost_equal(tau_calculated, tau_real)


if __name__ == "__main__":
    run_module_suite()
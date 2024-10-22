#!/usr/bin/env sage
import argparse
import json
import math
import time
from random import randint,random
#import instance_generation
from sage.all import GF, Integer, Matrix, PolynomialRing, prod, copy, vector, gcd

def my_monomials_of_degree(polyring, degree):
        """
        Return a list of all monomials of the given total degree in this
        multivariate polynomial ring.
        EXAMPLES::
            sage: R.<x,y,z> = ZZ[]
            sage: mons = R.monomials_of_degree(2)
            sage: mons
            [x^2, x*y, x*z, y^2, y*z, z^2]
        The number of such monomials equals `\binom{n+k-1}{k}`
        where `n` is the number of variables and `k` the degree::
            sage: len(mons) == binomial(3+2-1,2)
            True
        """
        from sage.combinat.integer_vector import IntegerVectors
        return [polyring.monomial(*a) for a in IntegerVectors(degree, polyring.ngens())]


class DecodeResult:
    def __init__(self, time_to_detect, solns):
        self.time_to_detect = time_to_detect
        self.solns = solns

# --------------------------------------------------
# HELPER FUNCTIONS 

def print_current_pt_distr(message, x_coords_list, search_pt, z, x_indics):
    print_pts = [0] * (len(x_coords_list)) 
    for j in range(len(message)):
        if x_indics[j] == 1:
            stalker_l = 0
            for i in range(len(x_coords_list)):
                if (z - message[j][0]).divides(x_coords_list[i]):
                    stalker_l = i
                    break
            print_pts[stalker_l] += 1
    search_pt_idx = -1
    for i in range(len(x_coords_list)):
        amt = print_pts[i]
        if (z - search_pt).divides(x_coords_list[i]):
            search_pt_idx = i
        print("{} polynomial has {} pts".format(i, amt))
    print("A point from the {} polynomial is the search point".format(search_pt_idx))

def identify_poly_found(solution_polys, sol_found):
    sol_idx = -1
    for i in range(len(solution_polys)):
        found_sol = True 
        # assume everything is the same size (it SHOULD be)
        for j in range(len(solution_polys[i])): 
            if sol_found[j] != solution_polys[i][j]:
                found_sol = False
                break
        if found_sol:
            sol_idx = i
            break
    print("Found polynomial solution corresponding to {}".format(sol_idx)) 

def scale_by(row, elt):
    scaled_row = []
    for row_val in row:
        scaled_row.append(row_val * elt)
    return scaled_row


def add_vectors(row1, row2):
    res = []
    for i in range(len(row1)):
        res.append(row1[i] + row2[i])
    return res

def make_sol_vector(list_polys, errors):
    sol_vec = [1]
    for i in range(len(list_polys)):
        sol_vec.append(list_polys[i])
    return scale_by(sol_vec, errors)

def test_comb(input_mtx, sol_vector):
    input_comb = []
    #col_mtx = input_mtx.transpose()
    if input_mtx.nrows() == input_mtx.ncols():
        inv_mtx = input_mtx.transpose().inverse()
        return inv_mtx*vector(sol_vector)
    else:
        input_mtx.insert_row(sol_vector)
        col_mtx = input_mtx.transpose()
        res = col_mtx.echelon_form()
        import pdb; pdb.set_trace()
        

# going to run a battery of tests to figure out really quickly WHAT
# is causing this weird behavior

def compute_norm(elt):
    max_deg = 0
    for i in elt:
        if i.degree() > max_deg:
            max_deg = i.degree()
    return max_deg

def find_sv_len(mtx):
    sv_len = compute_norm(mtx[0])
    for i in range(mtx.nrows()-1):
        cur_len = compute_norm(mtx[i+1])
        if cur_len < sv_len:
            sv_len = cur_len
    return sv_len

def barycentric_interpolate(Ls, w, ys, locs):
    return sum(ind * yi * Li * wi for ind, Li, wi, yi in zip(locs, Ls, w, ys))


def lagrange_basis(z, zs, pR):
    L = prod((z - zi) for zi in zs)
    Ls = [pR(L / (z - zi)) for zi in zs]
    Linvs = [1 / Li for Li in Ls]
    w = [Li(zi) for Li, zi in zip(Linvs, zs)]
    return L, Ls, w


def is_unique(some_msg):
    x_coords = [x[0] for x in some_msg]
    # unique = True

    # for x_coord in x_coords:
    #    if x_coords.count(x_coord) != 1:
    #        unique = False
    return len(x_coords) == len(set(x_coords))


# dropping the unused pos. stuff
def transl_to_set(idx_set):
    c_list = [idx_set[0]]
    for i in range(len(idx_set) - 1):
        c_list.append(idx_set[i + 1] - idx_set[i] - 1)
    return c_list


class CHDecoder:
    def __init__(self, pR, c, n, ell, agreement, multiplicity, shift):
        self._c = c
        self._n = n
        self._ell = ell
        self._agreement = agreement
        self._pR = pR
        self._z = pR.gens()[0]
        # check that parameters are appropriately set
        if agreement < math.ceil(
            (1.0 / (self._c + 1.0)) * (self._n + self._c * (self._ell))
        ):
            raise ValueError("Parameter set is not decodable!")
        if multiplicity != 1 or shift != 1:
            raise ValueError(
                "Cannot currently handle multiplicity or shift higher than one!"
            )
        self._k = multiplicity
        self._t = shift

        # set-up "globals"
        self.S = PolynomialRing(pR, c, "x", order="lex")
        self.xs = my_monomials_of_degree(self.S, 1)
        self.M_LIST = []
        for i in range(self._t + 1):
            self.M_LIST += my_monomials_of_degree(self.S, i)

    def create_interpols(self, message, locs):
        f = []
        for i in range(self._c):
            ys = [m[1][i] for m in message]
            fi = barycentric_interpolate(self.Ls, self.w, ys, locs)
            f.append(fi)
        return f

    def unweightdual(self, M, i):
        resp = []
        for j, monomial in enumerate(self.M_LIST):
            deg_v = monomial.degree()
            pt = M[i][j] / self._z ^ (self._ell * (self._t - deg_v))
            resp.append(self._pR(pt))
        return resp

    def find_agreeing_pts(self, polys, message, all_points):
        agree_pts = set()
        for pt in all_points:
            find_pt = 0
            for j in range(self._n):
                x_coord, y_coords = message[j]
                if x_coord == pt:
                    find_pt = j
                    break
            x_coord, y_coords = message[find_pt] 
            matches_all = True
            for i in range(self._c):
                try:
                    if polys[i](x_coord) != y_coords[i]:
                        matches_all = False
                        break
                except: 
                    raise ValueError("Failed in finding agreeing points phase!")
            if matches_all:
                agree_pts.add(pt)
        return agree_pts

    def remove_pts(self, message, resp_polys, x_indics):
        for i in range(len(message)):
            x_coord, y_coords = message[i]
            matches_all = True
            for j in range(self._c):
                if resp_polys[j](x_coord) != y_coords[j]:
                    matches_all = False
                    break
            if matches_all:
                x_indics[i] = 0
        return x_indics

    def first_step(self, message, locs):
        lagr_polys = []
        if locs.count(1) == len(message):
            lagr_polys = self.a_list
        else:
            lagr_polys = self.create_interpols(message, locs)
        N = self.N
        for idx in range(len(locs)):
            if locs[idx] == 0:
                N = self._pR(N / (self._z - message[idx][0]))
        M_D = Matrix(self._pR, self._c + 1)
        M_D[0, 0] = self._z ^ self._ell

        for i in range(self._c):
            M_D[0, i + 1] = lagr_polys[i]
            M_D[i + 1, i + 1] = N
        A = M_D.popov_form()
        return A

    def construct_one_out(self, basis_vectors, amplify, err_poly):
        for_testing = copy(basis_vectors)
        n_rows = len(for_testing)
        for i in range(n_rows):
            for_testing[i][0] *= amplify
            add_identity_row = [0]*i + [1] + [0]*(n_rows-i-1)
            for_testing[i] = for_testing[i] + add_identity_row

        num_cols = len(for_testing[0])
        last_row = [err_poly*amplify] + (num_cols-1)*[0]
        for_testing.append(last_row)
        check_vals = Matrix(for_testing).change_ring(self._pR).popov_form()
        
        return check_vals

    def add_shortest_vectors(self,mtx):
        shortest_len = find_sv_len(mtx)
        add_all_short_vecs = [0] * mtx.ncols()
        #add_all_short_vecs = copy(mtx[-1])
        for itr in range(mtx.nrows()):
            itr_vec = mtx[itr]
            if compute_norm(itr_vec) == shortest_len:
                add_all_short_vecs = add_vectors(add_all_short_vecs, itr_vec)
        return list(add_all_short_vecs)

    def list_decode(self, message):
        #global x_coords_list, valid_polys

        done_first_detection = False
        time_to_detect = -1
        detection_start = time.time()

        if len(message) < self._agreement:
            return 0, []
        
        self.x_coords = [m[0] for m in message]
        self.N, self.Ls, self.w = lagrange_basis(self._z, self.x_coords, self._pR)
        x_indics = [1] * len(message)
        self.a_list = self.create_interpols(message, x_indics)
        solns = []
        clfs = True  # continue-looking-for-solutions
        while clfs:
            A = self.first_step(message, x_indics)
            # first simple check to see if there is potentially at least one solution
            sv_len = find_sv_len(A)
            ub_on_sol = x_indics.count(1) - self._agreement + self._ell
            if sv_len > ub_on_sol:
                clfs = False
                continue
            # add up the shortest vectors, is it a solution? 
            comb_svs = self.add_shortest_vectors(A) 
            comb_svs[0] = self._pR(comb_svs[0] / self._z**self._ell)
            if comb_svs[0].divides(comb_svs[1]):
                resp_polys = comb_svs[1:]
                resp_polys = [
                    self._pR(x / comb_svs[0])
                    for x in resp_polys
                ]
                if resp_polys[0].degree() <= self._ell:
                    if not done_first_detection:
                        done_first_detection = True
                        time_to_detect = time.time() - detection_start
                    solns.append(resp_polys)
                self.remove_pts(message, resp_polys, x_indics)
            elif sv_len == ub_on_sol:
                # there cannot possibly be any solutions (if there were, either the last step would have succeeded or this vector would be shorter, fail)
                clfs = False
                continue
            else:
                # checking for hard multi-solution cases
                # first part does work of deciding which points to use to craft the second lattice
                excl_fact = self.N
                for i in range(A.nrows()):
                    if compute_norm(A[i]) <= ub_on_sol:
                        excl_fact = gcd(excl_fact, A[i][0])
                excl_pts = []
                for factor,deg in excl_fact.factor():
                    if deg == 1:
                        excl_pts.append(-factor.constant_coefficient())
                all_points = set()
                for idx, is_present in enumerate(x_indics):
                    if is_present == 1 and not message[idx][0] in excl_pts:
                        all_points.add(message[idx][0])

                err_term = 1
                cnp = len(all_points) + len(excl_pts)
                sv_bound = cnp - self._agreement + self._ell 
                search_pt = all_points.pop()
                # take ALL vectors below the sv_bound here to structure the 
                # sub-lattice problem
                bvs = []
                for i in range(A.nrows()):
                    row_norm = compute_norm(A[i])
                    if row_norm <= ub_on_sol:
                        bvs.append(self.unweightdual(A,i))

                err_term *= (self._z - search_pt)
                weight_factor = self._z**(cnp) 
                # second lattice reduction inside function
                mtx_out = self.construct_one_out(bvs, weight_factor, err_term)
                all_points.add(search_pt)
                sv_len = find_sv_len(mtx_out)
                total_vec = [0]*(self._c+1)
                # reconstruct vectors in A from this sub-lattice -- in particular add up the shortest vectors -- all entries in this vector should be a multiple of (z-search_pt)
                for itr in range(mtx_out.nrows()):
                    if compute_norm(mtx_out[itr]) == sv_len:
                        recon_vec = [0]*(self._c+1)
                        for j in range(len(bvs)):
                            mtx_itr = j - len(bvs)
                            recon_vec = add_vectors(recon_vec, scale_by(bvs[j], mtx_out[itr][mtx_itr]))
                        total_vec = add_vectors(total_vec,recon_vec)
                total_vec[0] /= weight_factor
                excl_poly = total_vec[1:]
                excl_poly = [
                    (self._pR(x) / self._pR(total_vec[0]))
                    for x in excl_poly
                ]
                # sometimes we get lucky and excl_poly is directly a solution 
                if excl_poly[0].denominator() == 1 and excl_poly[0].numerator().degree() <= self._ell:
                    if not done_first_detection:
                        done_first_detection = True
                        time_to_detect = time.time() - detection_start
                    solns.append(excl_poly)
                    self.remove_pts(message, excl_poly, x_indics)
                # sometimes, excl_poly is rational and agrees with everything in the input EXCEPT the soln set associated with search_pt -- to find this set therefore we can do lagr. interpol. on all points that DO NOT agree with the poly.
                ag_pts = self.find_agreeing_pts(excl_poly, message,all_points)
                precon_xs = all_points - ag_pts
                if len(precon_xs) < self._agreement:
                    continue
                precon_li = []
                for pt in precon_xs:
                    find_pt = 0
                    for j in range(self._n):
                        x_coord, y_coords = message[j]
                        if x_coord == pt:
                            find_pt = j
                            break
                    precon_li.append(message[find_pt])
                poly_recon_att = []
                for i in range(self._c):
                    xy_v = [(precon_li[j][0], precon_li[j][1][i]) for j in range(len(precon_li))]
                    poly_recon_att.append(self._pR.lagrange_polynomial(xy_v))
                if compute_norm(poly_recon_att) <= self._ell:
                    if not done_first_detection:
                        done_first_detection = True
                        time_to_detect = time.time() - detection_start
                    solns.append(poly_recon_att)
                    self.remove_pts(message, poly_recon_att, x_indics)    
            if x_indics.count(1) < self._agreement:
                clfs = False  
        if not done_first_detection:
            done_first_detection = True
            time_to_detect = time.time() - detection_start
        return DecodeResult(time_to_detect, solns)


if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("c", help="The number of polynomials to use", type=int)
    parser.add_argument("n", help="The total number of points to consider", type=int)
    parser.add_argument("ell", help="The degree of the polynomials", type=int)
    parser.add_argument(
        "agreement",
        help="The minimum necessary agreement for points to decode",
        type=int,
    )
    parser.add_argument(
        "--multiplicity",
        help="The multiplicty parameter of the decoding algorithm (default 1)",
        type=int,
        default=1,
    )
    parser.add_argument(
        "--shift",
        help="The shift parameter of the decoding algorithm (default 1)",
        type=int,
        default=1,
    )
    args = parser.parse_args()

    c = args.c
    n = args.n
    ell = args.ell
    agreement = args.agreement
    k = args.multiplicity
    t = args.shift

    # Setup algebraic objects
    field = GF((Integer(2 ** 22).previous_prime()))
    pR = PolynomialRing(field, "z")
    decoder = CHDecoder(pR, c, n, ell, agreement, k, t)

    poss_stalkers = int(math.floor(n / agreement))
    # change to always try for as many stalkers 
    # as possible 
    num_stalkers = poss_stalkers
    #num_stalkers = randint(0, poss_stalkers)
    e = n - num_stalkers * agreement
    list_stalkers = [agreement] * num_stalkers
    for i in range(num_stalkers):
        if e != 0:
            add_xtra = randint(0,e)
            e -= add_xtra
            list_stalkers[i] += add_xtra
     
    #print("Input is valid sets {} and errors {}".format(list_stalkers, e))
    valid_polys = []
    input_words = []
    #x_coords_list = []
    # we're going to see what happens when we inject polynomials of *arbitrary* 
    # degree but not chosen purely maliciously
    # this is what Matt was talking about yesterday with an channel where you can 
    # choose arbitrarily malicious stuff *without* seeing the input from the other party
    off_deg = randint(0,num_stalkers)
    deg_list = [ell] * (num_stalkers - off_deg)
    """
    for i in range(off_deg):
        deg = randint(1,n)
        if random() < 0.25:
            deg = -1
        deg_list.append(deg)
    deg_list = [int(x) for x in deg_list]
    deg_list.sort()
    """
    # if you're injecting params for testing, you better do it here! 
    #list_stalkers = [int(156), int(152), int(152), int(152)]
    #deg_list = [int(-1), int(67), int(134), int(354)]
    #e = int(0) 

    num_recov = len(list_stalkers)
    rand_inj = 0
    """
    for i in deg_list:
        if i < 0:
            rand_inj += 1
        elif i <= ell:
            num_recov += 1
        else:
            break
    """
    valid_polys, input_words = instance_generation.gen_adversarial_instance(
        field, pR, ell, c, list_stalkers + [e]
    )

    if not is_unique(input_words):
        raise Exception("x-coordinates are not unique")

    start_time = time.time()
    list_sol = decoder.list_decode(input_words)
    dur_full = time.time() - start_time
    import pdb; pdb.set_trace()
    all_present = True
    is_covered = []
    # chop all the polys that don't *need* to be recovered 
    valid_polys = valid_polys[rand_inj:]
    valid_polys = valid_polys[:num_recov]
    # this doesn't have to be the same size here, just make sure that each polynomial that should be recovered
    # is in the list 
    for poly_set in valid_polys:
        if poly_set not in list_sol:
            all_present = False
            break

    #if len(list_sol) == len(valid_polys):
    #    all_present = True
    #    for item in valid_polys:
    #        if item not in list_sol:
    #            #print("Should have recovered a polynomial that was not found in the list")
    #            all_present = False
    #            break
    #else:
    #    #print("Recovered {} polynomials. Should have recovered {}!".format(len(valid_polys),len(list_sol)))
    #    all_present = False
   
    num_sols_found = len(list_sol)
   
    # return some output
    result = (
        dur_full,
        all_present,
        num_sols_found,
        list_stalkers,
        ell,
        int(e),
    )
    res_str = json.dumps(result)
    print(res_str)

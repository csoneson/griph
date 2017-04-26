#include <R.h>
#include <Rinternals.h>
#include <stdlib.h> // for NULL
#include <R_ext/Rdynload.h>

/*
 registering of native routines is now (R 3.4) required
 by R CMD check.
 
 the content of this file was auto-generated by calling:
   tools::package_native_routine_registration_skeleton(".")
 in the package root directory
 
 furthermore, the following was added to NAMESPACE:
 useDynLib(griph, .registration = TRUE)
*/

/* .Call calls */
extern SEXP griph_HellingerMat(SEXP);
extern SEXP griph_JSDmat(SEXP);

static const R_CallMethodDef CallEntries[] = {
    {"griph_HellingerMat", (DL_FUNC) &griph_HellingerMat, 1},
    {"griph_JSDmat",       (DL_FUNC) &griph_JSDmat,       1},
    {NULL, NULL, 0}
};

void R_init_griph(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
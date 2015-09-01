#include <iostream>
#include <fstream>
#include <cstdlib>
#include <itpp/itbase.h>
#include <cpp/dev_random.cpp>
#include <cpp/itpp_ext_math.cpp>
#include <cpp/spinchain.cpp>
#include <math.h>
#include <tclap/CmdLine.h>
#include <device_functions.h>
#include <cuda.h>
#include <tools.cpp>
#include "cuda_utils.cu"
#include "model.cu"
#include "ev_routines.cu"
#include "ev_math.cu"
#include "cuda_functions.cu"
#include "ex_model.cu"
#include <time.h>


TCLAP::CmdLine cmd("Command description message", ' ', "0.1");
// TCLAP::ValueArg<unsigned int> CseedArg("","Cseed", "Random seed [0 for urandom]",false, 0,"unsigned int",cmd);
TCLAP::ValueArg<unsigned int> EseedArg("","Eseed", "Random seed [0 for urandom]",false, 0,"unsigned int",cmd);
TCLAP::ValueArg<unsigned int> PARAMseedArg("","PARAMseed", "Random seed [0 for urandom]",false, 0,"unsigned int",cmd);
TCLAP::ValueArg<string> optionArg("o","option", "Option" ,false,"nichts", "string",cmd);
TCLAP::ValueArg<int> nqubitsArg("q","qubits", "Number of qubits",false, 3,"int",cmd);
TCLAP::ValueArg<int> numtArg("","t", "Number of time iterartions",false, 1,"int",cmd);
TCLAP::ValueArg<double> JArg("","Jc", "Ising interaction in the z-direction",false, 0.,"double",cmd);
TCLAP::ValueArg<double> JpArg("","Jp", "Ising interaction between A and B",false, 0.,"double",cmd);
TCLAP::ValueArg<double> DJs("","DJs", "Delta in the Js interacions on chain",false, 0.,"double",cmd);
TCLAP::ValueArg<double> Js("","Js", "Center of the Js interactions on chain",false, 0,"double",cmd);
TCLAP::ValueArg<double> bx("","bx", "Magnetic field in x direction",false, 0,"double",cmd);
TCLAP::ValueArg<double> by("","by", "Magnetic field in y direction",false, 0,"double",cmd);
TCLAP::ValueArg<double> bz("","bz", "Magnetic field in z direction",false, 0,"double",cmd);
TCLAP::ValueArg<int> kx("","kx", "Momentum field in x direction",false, 0,"int",cmd);
TCLAP::ValueArg<double> Dbs("","Dbs", "Delta in the magnetic field on spins",false, 0,"double",cmd);
TCLAP::ValueArg<int> one_state("","one_state", "State l",false, 0,"int",cmd);
TCLAP::ValueArg<int> ifrandom("","ifrandom", "0 if you dont want randstate",false,1,"int",cmd);
TCLAP::ValueArg<int> dev("","dev", "Gpu to be used, 0 for k20, 1 for c20",false, 0,"int",cmd);
TCLAP::SwitchArg no_general_report("","no_general_report","Print the general report", cmd);
TCLAP::ValueArg<string> modelArg("","model", "Option" ,false,"nichts", "string",cmd);
TCLAP::ValueArg<int> tAvg("","t_ave", "Number of time averaged over",false, 1,"int",cmd);
TCLAP::ValueArg<int> xlenArg("","x", "Some number x",false, 0,"int",cmd);
TCLAP::ValueArg<int> symr("","symR", "If symmetries sectors of reflections are used",false, 0,"int",cmd);

int main(int argc,char* argv[]) {
  // Set initial stuff
  cout.precision(17);
  cudaSetDevice(dev.getValue());
  itpp::RNG_randomize();
  cmd.parse(argc,argv);
  string option=optionArg.getValue();
  string model=modelArg.getValue();
  double J=JArg.getValue();
  int nqubits = nqubitsArg.getValue();
  int numt=numtArg.getValue();
  int xlen=xlenArg.getValue();
  
  
  int l=pow(2,nqubits);    
  int nqubits_env,xl;
  
  itpp::ivec conxA,conxB;
  
  //Se elige el modelo a usar
  void (*evolution)(double *, double *, double, itpp::vec, int, int);
  evolution=model::lattice;
  nqubits_env=nqubits-1;

//   int Cseed=CseedArg.getValue();
  int PARAMseed=PARAMseedArg.getValue();int Eseed=EseedArg.getValue();
  
//   if (Cseed == 0 ){
//     Random seed_uran1; 
//     Cseed=seed_uran1.strong();
//   }
  itpp::RNG_reset(Cseed);
  //ESTADO INICIAL C
  itpp::cvec cstate = itppextmath::RandomState(2);
  
  if (Cseed == -1 ){
    cstate = itpp::ones_c(2);
    cstate=cstate*(1/sqrt(2));
  }
  
  if (Eseed == 0 ){
    Random seed_uran3; 
    Eseed=seed_uran3.strong();
  }
  itpp::RNG_reset(Eseed);
  
  itpp::cvec state;
  if(xlen==0) {
    itpp::cvec estate = itppextmath::RandomState(l/2);
  
    //Preparacion estado inicial
    state=tensor_prod(cstate,estate);
  }
  else {
    xl=pow(2,xlen);
    itpp::cvec estateA = itppextmath::RandomState(xl);
    itpp::cvec estateB = itppextmath::RandomState(l/(xl*2));
  
    //Preparacion estado inicial
    state=tensor_prod(cstate,tensor_prod(estateB,estateA)); 
  }
  
  //PARAMETROS SEED
  if (PARAMseed == 0 ){
    Random seed_uran2; 
    PARAMseed=seed_uran2.strong();
  }
  itpp::RNG_reset(PARAMseed);
  itpp::vec js = itpp::ones(nqubits_env)*(Js.getValue()-DJs.getValue()) + itpp::randu(nqubits_env)*(2*DJs.getValue());

  // Campo magnético
  itpp::vec b_one(3); b_one(0)=bx.getValue(); b_one(1)=by.getValue(); b_one(2)=bz.getValue();
  itpp::vec b(3);
  b(0)=b_one(0);
  b(1)=0;
  b(2)=b_one(2);
  
  //Se sube el estado al dev
  double *dev_R,*dev_I;
  evcuda::itpp2cuda_malloc(state,&dev_R,&dev_I);

  // Se calculan las trazas
  itpp::cvec stateBra=state;
  for (int t = 0; t < numt; t++) {
    evolution(dev_R,dev_I,J,b,nqubits,xlen);
    evcuda::cuda2itpp(state,dev_R,dev_I);
    cout<<norm(itpp::dot(itpp::conj(stateBra),state))<<endl;
  }
}

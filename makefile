-include ~/makefile

LDLIBS = -litpp
NVCCFLAGS= -arch=sm_13
GCCBIND = --compiler-bindir /usr/bin/g++-4.8.4 


INCLUDES := -I ../libs/


# Carlos Pineda {{{
ifeq ($(LOGNAME),carlosp)
    INCLUDES := -I. -I/home/carlosp/investigacion/libs/ -I/home/carlosp/investigacion/libs/qubits-CUDA -I../
endif
# }}}

# }}}


mein :: mein.cpp
	g++ $(INCLUDES) $< -o $@ $(LDLIBS)

abc :: abc.cu 
	nvcc $(INCLUDES) $< -o $@ $(LDLIBS)
	
win :: windows.cu 
	nvcc $(INCLUDES) $< -o $@ $(LDLIBS)
def :: def.cu 
	nvcc $(INCLUDES) $< -o $@ $(LDLIBS)
opar :: oparts.cu 
	nvcc $(INCLUDES) $< -o $@ $(LDLIBS)
dav :: dav.cu 
	nvcc $(INCLUDES) $< -o $@ $(LDLIBS)

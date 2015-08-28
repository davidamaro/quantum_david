#from subprocess import call
#comando="def"
#filename="julano.dat"
#x=call(['def', '--bz', '0.6', '--bx', '0.6', '--option', 'get_matrix', '-q', '3'])
#target=open("julano.dat",'w')
#target.write(x)
#target.close()
import subprocess
import numpy as np
campo=np.linspace(0,np.pi/2,40);
#print(campo)
i=0
for valor in campo:
  filename="hor-%s.dat" %(i)
  with open(filename, "w") as output:
    subprocess.call(['dav', '--bx', "%s" %(valor),
        '-q', '16', '--t', '12', '--x', '4', '--Jc', '.5'], stdout=output)
  i+=1

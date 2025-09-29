# p4-lab
Práctica de P4. 

Basada en [P4-Utils](https://nsg-ethz.github.io/p4-utils/).

## Contenido
- files/escenario_red.py -> topología de red mininet usando P4-Utils.

- files/basico.p4 -> programa P4 sencillo basado en los [p4lang/tutorials](https://github.com/p4lang/tutorials.git)

- files/controlador.py -> controlador que usa la P4Runtime API mediante P4-utils

- files/avanzado_plantilla.p4 -> plantilla de un programa P4 que implementa un protocolo llamada TeP4.

- files/controlador_avanzado_plantilla.py -> plantilla de un controlador para el plano de datos creado con avanzado_plantilla.p4

- protobuf/ -> conjunto de ficheros .proto para que Wireshark decodifique tráfico en el plano de control de los conmutadores P4.
 

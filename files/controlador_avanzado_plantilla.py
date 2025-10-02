from p4utils.utils.sswitch_p4runtime_API import SimpleSwitchP4RuntimeAPI


# Creamos objeto para controlar sA (el que escucha en puerto grpc 9559)
# Adaptar nombres al programa P4 a cargar en el swicth.
controller = SimpleSwitchP4RuntimeAPI(device_id=1, grpc_port=9559,
                                      p4rt_path='avanzado_p4rt.txt',
                                      json_path='avanzado.json')


# TAREA: rellenar entradas en todas las tablas del switch según
# indicaciones posteriores. 

# Añadimos entradas a las tablas del switch con formato:
# controller.table_add('nombre_tabla', 'nombre_acción_a_ejecutar_si_match', ['valor de key que hace match', ...], ['salida de la entrada si hace match, que será parámetro de entrada para la acción', ...])

# Entradas en la tabla para comprobar si el switch es ingress switch, los 
# valores de key que harán match serán los números de puerto que vayan 
# hacia un sistema final. No hay parámetros de salida.
controller.table_add('check_is_ingress_border', '', [''])

# Entradas en la tabla para comprobar si el switch es egress switch, los 
# valores de key que harán "match" son los prefijos IP que incluyan las 
# direcciones de los sistemas finales conectados al switch. No hay 
# parámetros de salida.
controller.table_add('check_is_egress_border', '', [''])

# Entradas en la tabla para comprobar si el paquete está de vuelta al 
# ingress switch, los valores de key que harán "match" son la dirección 
# MAC de las interfaces del switch que vayan hacia sistemas finales. No 
# hay parámetros de salida.
controller.table_add('check_is_back', '', [''])

# Entradas en la tabla para seleccionar la "route" en función del 
# protocolo transportado por el paquete IP. Introducir dos entradas, una 
# para el tráfico ICMP (protocolo=1 en cabecera IP) y otra para tráfico 
# UDP (protocolo=0x11). El tráfico ICMP hay que asignarlo a la "route" 1  
# y el UDP a la "route" 2. 
controller.table_add('choose_path', '', [''], [''])
controller.table_add('choose_path', '', [''], [''])

# Entradas en la tabla para encaminar los paquetes en función del campo 
# "route" de la cabecera de nuestro protocolo. La clave que hace "match"
# son las dos posibles "route" y la salida son la MAC del siguiente salto 
# y el puerto de salida de acuerdo a la ruta. La "route" 1 debe reenviar
# los paquetes en el sentido de las agujas del reloj, y la 2 en el contrario. 
controller.table_add('miheader_tbl', '', [''], ['',''])
controller.table_add('miheader_tbl', '', [''], ['',''])

# Entradas en la tabla IP para encaminar a los sistemas finales. Los 
# valores de key que harán match serán prefijos que incluyan las 
# direcciones de los sistemas finales conectados al switch. La salida
# es la dirección MAC del siguiente salto (el sistema final) y el puerto
# de salida del switch hacia el sistema final.
controller.table_add('ipv4_lpm', '',[''], ['',''])



# Switch B
# TAREA: lo mismo para el sB 


# Swicth C
# TAREA: lo mismo para el sC

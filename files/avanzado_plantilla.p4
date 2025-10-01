/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}


/* TAREA: Esta es la definición de la cabecera del protocolo
especificado en el enunciado (TeP4). Hay que rellenar esta cabecera definiendo 
los campos de la misma según la especificación. Los campos
se deben llamar route, reserved, y swt para ser compatibles
con el resto del código (puede cambiar los nombres, pero entonces
deberá hacerlo también en los casos correspondientes del código
proporcionado). */
header miheader_t {


}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

/* Definimos dos bits de metadatos asociados a los paquetes que
se procesan para poder guardar si el switch que hace el procesamiento
es el ingress (en la red) o el egress (de la red). */
struct metadata {
    bit<1> is_ingress_border;
    bit<1> is_egress_border;
}

struct headers {
    ethernet_t   ethernet;
    miheader_t   miheader;
    ipv4_t       ipv4;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

/* Aquí analizamos la cabecera Ethernet del paquete y extraemos
los campos correspondientes (el método extract se encarga de ello).
Según el valor del campo etherType de la cabecera Ethernet, la
siguiente cabecera será la del protocolo TeP4 (etherType=0x8847,
valor escogido por nosotros) o una cabecera IP, en consecuencia se 
llama al análisis de la cabecera correspondiente. */
    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            0x8847: parse_miheader;
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

/* Analizamos la cabecera del protocolo TeP4. Nuestro protocolo solo
transporta paquetes IP, así que después de extraer esta cabecera, la 
siguiente es siempre una cabecera IP, por lo que llamamos al análisis 
de la misma. */
    state parse_miheader {
        packet.extract(hdr.miheader);
        transition parse_ipv4;
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);       
        transition accept;
    }


}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

/* Todo el procesamiento específico del protocolo TeP4 se va a hacer en
el Ingress*/ 
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop(standard_metadata);
    }

/* Acción que guarda como metadato que el switch es el ingress para
este paquete */
    action set_is_ingress_border(){
        meta.is_ingress_border = (bit<1>)1;
    }

/* Creamos una tabla para determinar si el switch es un ingress 
switch para el paquete. La tabla recogerá como clave los puertos que
van a sistemas finales, será rellenada por el plano de control, y
si el puerto de entrada del paquete es exactamente uno de ellos, habrá
que realizar la acción set_is_ingress_border. */
    table check_is_ingress_border {
        key = {
            standard_metadata.ingress_port: exact;
        }
        actions = {
            NoAction;
            set_is_ingress_border;
        }
        default_action = NoAction;
    }

/* Acción si el switch es el egress para el paquete. En ese caso, se
declara invalida la cabecera del protocolo TeP4, se guarda como
metadato que el switch es egress, y se cambia el campo etherType de 
la cabecera Ethernet para indicar que transporta un paquete IP (y
ya no encapsulado en TeP4) */
    action set_is_egress_border() {
        hdr.miheader.setInvalid(); /* Hace inválida la cabecera, por lo que
                                      se quitará del paquete */
        meta.is_egress_border = (bit<1>)1;
        hdr.ethernet.etherType = TYPE_IPV4;
    }

/* Tabla para determinar si el switch es egress. Se hace comprobando si
tiene en la tabla IP cómo llegar a la dirección IP destino. El plano de
control solo rellanará las tablas IP con direcciones IP de los sistemas
finales conectados al switch */ 
    table check_is_egress_border {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            NoAction;
            set_is_egress_border;
        }
        default_action = NoAction;

    }

/* Esta acción crea y añade la cabecera del protocolo TeP4. 
*/
    action add_miheader_header(bit<8> route) {
        hdr.miheader.setValid(); /* con isValid() se puede comprobar si
                                    una cabecera es válida para tenerla 
                                    en el paquete o no */
        hdr.miheader.route=  /* TAREA: completar */
        hdr.miheader.swt=    /* TAREA: completar-> dirección MAC por la que se ha recibido el paquete */
        hdr.ethernet.etherType = 0x8847;
    }

/* Esta tabla sirve para añadir la cabecera del protocolo TeP4
al paquete, rellenando los campos de la misma. El campo ruta dependerá
del campo de protocolo de la cabecera IP, por lo que la clave de esta 
tabla debe ser el protocolo de la cabecera IP, de modo que el plano
de control pueda indicar la ruta deseada para cada protocolo. Esta
tabla solo se aplicará en el ingress switch.
*/
    table choose_path {
        key= {
            hdr.ipv4.protocol: exact;      
        }
        actions = {
            NoAction;
            add_miheader_header;
        }
        default_action = NoAction;
    }

/* Esta tabla comprueba si la MAC incluida en la cabecera TeP4 del paquete 
es la MAC de alguna de las interfaces con sistemas finales en este switch. 
Si es así, hay que tirar el paquete (esta tabla solo se aplicará si el
switch no es el ingress). La tabla será rellenada por el plano de control
con las MACs de las interfaces correspondientes. 
*/
    table check_is_back {
        key = {
            hdr.miheader.swt: exact;
        }
        actions = {
            NoAction;
            drop;
        }
        default_action = NoAction;
    }

/* Esta es la acción para reenviar el paquete según la cabecera
TeP4 (se aplicará cuando lo indique la tabla miheader_tbl). */
    action miheader_forward (macAddr_t dstAddr, egressSpec_t port) {
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;

        standard_metadata.egress_spec = port;
    }

/* TAREA: Completar esta tabla que se usa para el reenvío en base al 
campo route de la cabecera TeP4. La clave será el campo route de nuestro 
protocolo. El match hará que se aplique la acción miheader_forward que define
cómo se reenvía el paquete. Si no hay match, se tira el paquete.
El plano de control rellenará esta tabla con, dada una ruta, la MAC destino y el puerto 
(parámetros de la acción miheader_forward) que hay que aplicar para el reenvío por esa 
ruta (definida por el valor del campo route del paquete).*/
    table miheader_tbl {
        key = {
            
        }
        actions = {
            
        }
        default_action = drop;
    }

    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
       
    } 

/* Reenvío por cabecera IP que solo usaremos para reenviar a 
sistemas finales */
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }


/* En el siguiente apply tenemos la lógica del procesamiento del paquete 
en la entrada al switch. La lógica debe ser la siguiente:

- Comprobar si el switch es el ingress del paquete, aplicando la tabla
correspondiente.

- Comprobar si el switch es el egress del paquete, aplicando la tabla 
correspondiente. 

- Si el switch es ingress pero no egress, aplicar la tabla para añadir 
la cabecera del protocolo TeP4.

- Si existe la cabecera TeP4 (la cabecera es válida),
aplicar la tabla para encaminar por TeP4.

- Si no existe la cabecera de TeP4 (no es válida), aplicar
la tabla para encaminar por IP.

- Si el switch no es el ingress, comprobar si el paquete ha vuelto al
switch aplicando la tabla correspondiente. Esta comprobación hay que 
hacerla al final porque, aunque la decisión sea tirar el paquete,
esa decisión no se implementa inmediatamente, por lo que si hacemos otro
procesamiento después y resulta en que al paquete se le asigna un reenvío, 
la decisión de tirar el paquete se perdería. 
*/

    /* TAREA: completar bloque apply, se copia las partes de la lógica explicada arriba que hay que implementar */
    apply {
       
       check_is_ingress_border.apply();
       
       /** TAREA: añadir código para Comprobar si el switch es el egress del paquete, aplicando la tabla 
           correspondiente. **/


       if((meta.is_ingress_border==1) && (meta.is_egress_border!=1)) {
            choose_path.apply();
       }

       /** TAREA: añadir código para: 
                 - Si existe la cabecera de nuestro protocolo (la cabecera es válida), aplicar la tabla 
                   para encaminar por nuestro protocolo.

                 - Else: Si no existe la cabecera de nuestro protocolo (no es válida), aplicar
                   la tabla para encaminar por IP.
       **/

       if (meta.is_ingress_border!=1) {
            check_is_back.apply();
       }

    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

     apply {}
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply {
        update_checksum(
        hdr.ipv4.isValid(),
            { hdr.ipv4.version,
              hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {

/* Se reconstruye el paquete para su envío, para lo que se le añaden las 
cabeceras. El método .emit solo añadirá una cabecera si es válida, 
cualquier cabecera que el procesamiento haya declarado inválida, 
no será añadida al paquete */        
        packet.emit(hdr.ethernet);
        packet.emit(hdr.miheader);
        packet.emit(hdr.ipv4);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;

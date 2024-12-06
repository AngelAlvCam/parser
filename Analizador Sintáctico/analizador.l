%{
    /*
    Analizador léxico-sintáctico para lenguaje definido en clase
    Compiladores 2023-1
    Autor: Angel Alvarado Campos
    Profesor: M.C. Laura Sandoval Montaño
    Fecha de entrega: 8 de diciembre

    Objetivo: Construir en un mismo programa, los analizadores léxico y sintáctico descendente
    recursivo que revisen programas escritos en el lenguaje definido por la gramática del Anexo A
    del documento de requisitos para este programa.

    Descripción: Se trata de un programa que implementa a las fases de análisis léxico
    y sintáctica de un compilador para un lenguaje definido en clase. Este analizador
    reconoce las 9 clases de componentes léxicos, distingue errores léxicos y sintácticos,
    e indica si un programa es correcto o no. También tiene como salidas a diferentes archivos
    de texto con información util sobre el proceso de compilación.
    */
   
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    //################## ESTRUCTURAS DE DATOS ###########################
    /*
        Definición de las estructuras de datos para las tablas de literales
        Lista ligada para tablas de literales (Clases 3 y 4)
    */
    typedef struct nodo_lit {
        int pos;    // Posicion
        char* dato; // Dato
        struct nodo_lit* next;
    } nodo_lit;

    /*
        Definición de estructura de datos para tabla de símbolos
        Lista ligada para tabla de símbolos (Clase 1)
        No permite duplicados
    */
    typedef struct nodo_tabsim {
        int pos;    // Posición
        char* nombre_id;    // Nombre del identificador
        int tipo;   // Tipo de dato: Inicial es -1 
        struct nodo_tabsim* next;
    } nodo_tabsim;

    /*
        Definición de estructura de datos para la cadena de atomos. Es en esencia
        una lista ligada que no verifica si hay elementos duplicados. El dato que se
        almacena en cada nodo es un caracter que representa al átomo.
    */
    typedef struct nodo_atomo {
        char atomo;     // Valor del átomo
        struct nodo_atomo* next;    // Átomo siguiente
    } nodo_atomo;

    //################## PROTOTIPOS DE FUNCIONES ###########################
    int insertar_simbolo(nodo_tabsim**,char*);
    int buscar_simbolo(nodo_tabsim*, char*);
    int print_tabsim(nodo_tabsim*);
    int insertar_literal(nodo_lit**,char*,int);
    int print_tablit(nodo_lit*);
    int valor_palRes(char*);
    int valor_opRela(char*);
    char atomo_opRela(char*);
    char atomo_palRes(char*);
    int insertar_atomo(nodo_atomo**,char);

    //################## INICIALIZACIONES ###########################
    // Inicialización de tablas de literales
    int num_Reales = -1;
    int num_Constantes = -1;
    nodo_lit* head_Real = NULL; // Tabla de literales de constantes reales (clase 3)
    nodo_lit* head_Cadenas = NULL;  // Tabla de literales de constantes cadenas (clase 4)

    // Inicializacion de tabla de símbolos
    int num_identificadores = -1;
    nodo_tabsim* head_tabsim = NULL;    // Tabla de símbolos (clase 1) 

    int num_atomos = 0; // Inicia a contar átomos desde 0: 0 significa, 0 átomos en cadena
    nodo_atomo* head_atomos = NULL; // Inicializa cadena de átomos, se va llenando en la ejecución

    char* cadena_atomos = NULL; // Cadena de átomos final, es entrada del analizador sintáctico

    int linea = 0; // Contador de saltos de linea
    int errores_lexicos = 0;    // Contador de errores léxicos
    int errores_sintacticos = 0;    // Contador de errores sintácticos

    // Archivos
    FILE* LiteralesReales;
    FILE* LiteralesCadenas;
    FILE* Simbolos;
    FILE* Tokens;
    FILE* Errores;
    FILE* Atomos;
    
    //################## DEFINICION DE FUNCIONES ###########################
    /*
        Función que permite realizar la inserción de un identificador en la tabla
        de símbolos. No permite la inserción de valores duplicados.
        Tiene como valor de retorno a un entero que denota la posición en la que
        el identificador fue insertado en la lista, en un rango de posiciones de
        [0, size - 1].
        Si el identificador argumentado ya se encuentra en la lista, entonces se tendrá
        como valor de retorno a la posición del identificador en la tabla de símbolos.
    */
    int insertar_simbolo (nodo_tabsim** head, char* identificador){
        if (buscar_simbolo(*head,identificador) >= 0){
            return buscar_simbolo(*head,identificador);
        } else {
            // Insertar
            num_identificadores++;
            int posicion = num_identificadores;
            nodo_tabsim* nodo_nuevo = (nodo_tabsim*) malloc(sizeof(nodo_tabsim));
            nodo_nuevo -> nombre_id = strdup(identificador);
            nodo_nuevo -> tipo = -1; // Inicial es -1: Se modificará en futuras entregas
            nodo_nuevo -> pos = posicion;
            nodo_nuevo -> next = NULL;
            if (*head == NULL){
                *head = nodo_nuevo;
            } else {
                nodo_tabsim* nodo_aux = *head;
                while (nodo_aux -> next != NULL){
                    nodo_aux = nodo_aux -> next; 
                }
                nodo_aux -> next = nodo_nuevo;
            }
            return nodo_nuevo -> pos;
        }
    }

    /*
        Función auxiliar, permite imprimir el contenido de la tabla de símbolos
    */
    int print_tabsim(nodo_tabsim* head){
        nodo_tabsim* current = head;
        while (current != NULL){
            printf("[%s]", current->nombre_id);
            current = current -> next;
        }
        return 0;
    }

    /*
        Función auxiliar de la función de insertar_simbolo. Se encarga de realizar la búsqueda
        de un identificador argumentado en la tabla de símbolos para identificar si es posible
        realizar la inserción, debido a que no se permiten duplicados en la tabla de símbolos.
        Si el identificador ya se encuentra en la tabla de simbolos, entonces se retorna la
        posición del identificador en la tabla.
        Por otro lado, si el identificador no se encuentra en la tabla se retorna un -1, para
        distinguir que el identificador no se encuentra en una posición de la tabla de simbolos.
    */
    int buscar_simbolo(nodo_tabsim* head, char* identificador){
        nodo_tabsim* current = head;
        while (current != NULL){
            if (strcmp(current -> nombre_id, identificador) == 0){
                // Retorna la posición del identificador en la tab. de simbolos
                return current -> pos;
            }
            current = current -> next;
        }
        // Retorna posición invalida, indicando que no se encuentra en la tabla
        return -1;
    }

    /*
        Permite obtener el valor correspondiente a cada
        palabra reservada (clase 0), según el catalogo
        descrito en los requerimientos del programa.
    */
    int valor_palRes(char* palabra){
        if (strcmp(palabra, "alternative") == 0){
            return 0;
        } else if (strcmp(palabra, "big") == 0) {
            return 1;
        } else if (strcmp(palabra, "evaluate") == 0) {
            return 2;
        } else if (strcmp(palabra, "instead") == 0) {
            return 3;
        } else if (strcmp(palabra, "large") == 0) {
            return 4;
        } else if (strcmp(palabra, "loop") == 0) {
            return 5;
        } else if (strcmp(palabra, "make") == 0) {
            return 6;
        } else if (strcmp(palabra, "number") == 0) {
            return 7;
        } else if (strcmp(palabra, "other") == 0) {
            return 8;
        } else if (strcmp(palabra, "real") == 0) {
            return 9;
        } else if (strcmp(palabra, "repeat") == 0) {
            return 10;
        } else if (strcmp(palabra, "select") == 0) {
            return 11;
        } else if (strcmp(palabra, "small") == 0) {
            return 12;
        } else if (strcmp(palabra, "step") == 0) {
            return 13;
        } else if (strcmp(palabra, "stop") == 0) {
            return 14;
        } else if (strcmp(palabra, "symbol") == 0) {
            return 15;
        } else {   
            // if palabra es "throw"
            return 16;
        }
    }

    /*
        Función que permite obtener el valor entero del
        operador relacional (clase 7), según lo descrito en el
        catalogo de operadores relacionales descrito
        en los requerimientos del programa.
    */
    int valor_opRela(char* operador){
        if (strcmp(operador, "<") == 0){
            return 0;
        } else if (strcmp(operador, ">") == 0){
            return 1;
        } else if (strcmp(operador, "<=") == 0){
            return 2;
        } else if (strcmp(operador, ">=") == 0){
            return 3;
        } else if (strcmp(operador, "==") == 0){
            return 4;
        } else {
            // if operador es "!="
            return 5;
        }
    }

    /*
        Permite insertar nuevos valores en las tablas de literales
        No verifica si hay duplicados para realizar la inserción, por lo cual se aceptan duplicados.
        Tiene como valor de retorno a la posición del nuevo valor en la tabla.
        Es usada para la tabla de literales de enteros (clase 1), reales (clase 2) y cadenas (clase 3)
    */
    int insertar_literal (nodo_lit** head, char* valor, int clase){
        int posicion = -1;
        if (clase == 3){ // Clase 3: Reales
            num_Reales++;
            posicion = num_Reales;
        } else if (clase == 4){ // Clase 4: Cadenas
            num_Constantes++;
            posicion = num_Constantes;
        }

        if (posicion != -1){    // Si es clase 3 o 4
            nodo_lit* nuevoNodo = (nodo_lit*) malloc(sizeof(nodo_lit));
            nuevoNodo -> dato = strdup(valor);
            nuevoNodo -> next = NULL;
            nuevoNodo -> pos = posicion;
            if (*head == NULL){
                *head = nuevoNodo;
            } else {
                nodo_lit* nodoAux = *head;
                while (nodoAux -> next != NULL){
                    nodoAux = nodoAux -> next;
                }
                nodoAux -> next = nuevoNodo;
            }
            return nuevoNodo -> pos;    // Retorna posición de la inserción actual
        }
        return -1;
    }

    /*
        Función auxiliar, permite imprimir el contenido de las tablas de literales
    */
    int print_tablit(nodo_lit* head){
        nodo_lit* current = head;
        while (current != NULL){
            printf("[%s]", current->dato);
            current = current -> next;
        }
        return 0;
    }

    /*
        Función que permite escribir el contenido de una tabla de literales 
        (de constantes numéricas reales o constantes cadenas) descrita por un nodo
        de tipo nodo_lit en un archivo argumentado de tipo FILE*.
    */
    int write_tablit(FILE* archivo, nodo_lit* head){
        nodo_lit* current = head;
        int posicion = 0;
        while (current != NULL){  
            fprintf(archivo, "%d\t%s\n", posicion, current->dato);
            current = current -> next;
            posicion++;
        }
        return 0;
    }

    /*
        Función que permite escribir el contenido de una tabla de simbolos
        descrita por un nodo de tipo nodo_tabsim en un archivo argumentado de tipo FILE*.
    */
    int write_tabsim(FILE* archivo, nodo_tabsim* head){
        nodo_tabsim* current = head;
        int posicion = 0;
        while (current != NULL){
            fprintf(archivo, "%d\t%s\t%d\n", posicion, current->nombre_id, -1);
            current = current -> next;
            posicion++;
        }
        return 0;
    }

    /*
        Función que permite leer el contenido de un archivo argumentado de tipo FILE*
        desde la terminal.
    */
    int read_file(FILE* archivo){
        char c_aux;
        fread(&c_aux,sizeof(char),1,archivo);
        while(feof(archivo) == 0){
            printf("%c",c_aux);
            fread(&c_aux,sizeof(char),1,archivo);
        }
        printf("\n\n");
        return 0;
    }

    /*
        Función para obtener un átomo para los operadores
        relacionales
    */
    char atomo_opRela(char* operador){
        if (strcmp(operador, "<") == 0){
            return '<';
        } else if (strcmp(operador, ">") == 0){
            return '>';
        } else if (strcmp(operador, "<=") == 0){
            return 'l';
        } else if (strcmp(operador, ">=") == 0){
            return 'u';
        } else if (strcmp(operador, "==") == 0){
            return 'e';
        } else {
            // if operador es "!="
            return 'd';
        }
    }

    /*
        Función para obtener un átomo para las palabras
        reservadas
    */
    char atomo_palRes(char* palabra){
        if (strcmp(palabra, "alternative") == 0){
            return 'a';
        } else if (strcmp(palabra, "big") == 0) {
            return 'b';
        } else if (strcmp(palabra, "evaluate") == 0) {
            return 'f';
        } else if (strcmp(palabra, "instead") == 0) {
            return 't';
        } else if (strcmp(palabra, "large") == 0) {
            return 'g';
        } else if (strcmp(palabra, "loop") == 0) {
            return 'w';
        } else if (strcmp(palabra, "make") == 0) {
            return 'm';
        } else if (strcmp(palabra, "number") == 0) {
            return '#';
        } else if (strcmp(palabra, "other") == 0) {
            return 'o';
        } else if (strcmp(palabra, "real") == 0) {
            return 'x';
        } else if (strcmp(palabra, "repeat") == 0) {
            return 'j';
        } else if (strcmp(palabra, "select") == 0) {
            return 'h';
        } else if (strcmp(palabra, "small") == 0) {
            return 'p';
        } else if (strcmp(palabra, "step") == 0) {
            return 'c';
        } else if (strcmp(palabra, "stop") == 0) {
            return 'q';
        } else if (strcmp(palabra, "symbol") == 0) {
            return 'y';
        } else {   
            // if palabra es "throw"
            return 'z';
        }
    }

    /*
        Función de inserción de átomos en la estructura de datos nodo_atomo.
    */
    int insertar_atomo(nodo_atomo** head, char valor){
        nodo_atomo* nuevo_atomo = (nodo_atomo*) malloc(sizeof(nodo_atomo));
        nuevo_atomo -> atomo = valor;
        nuevo_atomo -> next = NULL;
        if (*head == NULL){
            *head = nuevo_atomo;
        } else {
            nodo_atomo* nodoAux = *head;
            while (nodoAux -> next != NULL){
                nodoAux = nodoAux -> next;
            }
            nodoAux -> next = nuevo_atomo;
        }
        num_atomos++;
        return 0;
    }

    /*
        Función que permite, una vez llenada la estructura de datos nodo_atomo, convertir al contenido
        de esta estructura de datos en una cadena de caracteres. Tiene como tipo de retorno un apuntador a
        un arreglo de caracteres que representa a la cadena de átomos.
    */
    char* generar_cadena_atomos(nodo_atomo* head){
        char* cadena_atomos = malloc(sizeof(char) * (num_atomos+1));
        nodo_atomo* current = head;
        int i = 0;
        while (current != NULL){
            cadena_atomos[i] = current -> atomo; 
            current = current -> next;
            i++;
        }
        return cadena_atomos;
    }
%}

espacio [ \t\v\r]+
salto \n
palRes alternative|big|evaluate|instead|large|loop|make|number|other|real|repeat|select|small|step|stop|symbol|throw
identificador \$[A-Za-z]+
ctsNumReal ([1-9][0-9]*)?\.([0-9]+)
ctsNumEnt ([1-9][0-9]*)|(0)|([oO][0-7]+)
simEsp \[|\]|\(|\)|\{|\}|,|;|:
opArit (\+)|(\-)|(\*)|(\/)|(\%)|(\\)|(\^)
opRela (<)|(>)|(<=)|(>=)|(==)|(!=)
opAsig (=)
chars [^\'\"\n]
ctsCadenas (\"\'\")|(\'\"\')|(\'{chars}\')|(\"{chars}({chars}+)\")
error .


%%
{salto} {
    // Cuenta saltos de línea
    //printf("Salto de linea en linea: %d\n", linea);
    linea++;
    }
{espacio} {
    // Omite espacios entre los componentes
    //printf("Espacio en linea: %d\n", linea);
    ;
}
{palRes} {
    // CLASE 0
    fprintf(Tokens, "(0\t%d)\n", valor_palRes(yytext)); // Token clase 0
    insertar_atomo(&head_atomos, atomo_palRes(yytext)); // Se inserta el átomo, correspondiente a la palabra reservada
    fprintf(Atomos, "%d\t%c\n", num_atomos-1, atomo_palRes(yytext));    // Se añade el átomo al archivo txt de cadena de átomos
}
{identificador} {
    // CLASE 1
    fprintf(Tokens, "(1\t%d)\n", insertar_simbolo(&head_tabsim, yytext)); // Token clase 1
    insertar_atomo(&head_atomos, 'i');  // Se inserta el átomo i (identificador) a la cadena de átomos
    fprintf(Atomos, "%d\t%c\n", num_atomos-1, 'i'); // Se añade el átomo al archivo de texto de cadena de átomos
}
{ctsCadenas} {
    // CLASE 4
    fprintf(Tokens, "(4\t%d)\n", insertar_literal(&head_Cadenas, yytext, 4)); // Token clase 4
    insertar_atomo(&head_atomos, 's');  // Se añade el átomo s (cadenas) a la cadena de átomos
    fprintf(Atomos, "%d\t%c\n", num_atomos-1, 's'); // Se añade el átomo al archivo de texto de cadena de átomos
}
{ctsNumReal} {
    // CLASE 3
    // Prioridad sobre las enteras
    fprintf(Tokens, "(3\t%d)\n", insertar_literal(&head_Real, yytext, 3)); // Token clase 3
    insertar_atomo(&head_atomos, 'r');  // Se añade el átomo r (números reales) a la cadena de átomos
    fprintf(Atomos, "%d\t%c\n", num_atomos-1, 'r'); // Se añade el átomo al archivo de texto de cadena de átomos
}
{ctsNumEnt} {
    // CLASE 2
    fprintf(Tokens, "(2\t%s)\n", yytext); // Token clase 2
    insertar_atomo(&head_atomos, 'n');  // Se añade el átomo n (números enteros) a la cadena de átomos
    fprintf(Atomos, "%d\t%c\n", num_atomos-1, 'n'); // Se añade el átomo al archivo de texto de cadena de átomos
}
{opAsig} {
    // CLASE 8
    // Prioridad sobre los operadores relacionales
    fprintf(Tokens, "(8\t=)\n");    // Token clase 8
    insertar_atomo(&head_atomos, '=');  // Se añade el átomo =, de operador de asignación, a la cadena de átomos
    fprintf(Atomos, "%d\t%c\n", num_atomos-1, '='); // Se añade el átomo al archivo de texto de cadena de átomos
}
{opRela} {
    // CLASE 7
    fprintf(Tokens,"(7\t%d)\n", valor_opRela(yytext));  // Token clase 7
    insertar_atomo(&head_atomos, atomo_opRela(yytext)); // Se añade el átomo correspondiente a la operación relacional
    fprintf(Atomos, "%d\t%c\n", num_atomos-1, atomo_opRela(yytext));    // Se añade el átomo al archivo de cadena de átomos
}
{opArit} {
    // CLASE 6
    fprintf(Tokens, "(6\t%s)\n", yytext);   // Token clase 6
    insertar_atomo(&head_atomos, *yytext);  // Se añade un átomo, idéntico a la operación aritmética, a la cadena de átomos
    fprintf(Atomos, "%d\t%s\n", num_atomos-1, yytext);  // Se añade el átomo al archivo de cadena de átomos
}
{simEsp} {
    // CLASE 5
    fprintf(Tokens, "(5\t%s)\n", yytext); // Token clase 5
    insertar_atomo(&head_atomos, *yytext);  // Se añade el átomo, idéntico al símbolo especial, a la cadena de átomos
    fprintf(Atomos, "%d\t%s\n", num_atomos-1, yytext);  // Se añade el átomo al archivo de cadena de átomos
} 
{error} {
    fprintf(Errores, "ERROR LÉXICO: %s en linea %d\n", yytext, linea);
    errores_lexicos++; // Incremento en conteo de errores léxicos
}
%%

//################## PROTOTIPOS DE FUNCIONES RECURSIVAS ###########################
/*
    Las funciones que se enlistan como prototipos en las siguientes lineas fueron definidas
    en función de los conjuntos de selección de las producciones propuestas en la gramática
    del lenguaje.
*/
int PROGRAM();
int OTRAFUNC();
int FUNC();
int PARAM();
int OTROPARAM();
int CUERPO();
int DECL();
int D();
int TIPO();
int K();
int Q();
int N();
int B();
int C();
int A();
int APRIMA();
int E();
int EPRIMA();
int T();
int TPRIMA();
int F();
int R();
int RPRIMA();
int V();
int VPRIMA();
int VPRIMA2();
int VPRIMA3();
int P();
int LISTAP();
int W();
int I();
int IPRIMA();
int J();
int Y();
int X();
int Z();
int H();
int CPRIMA();
int OPRIMA();
int U();
int DEVUELVE();
int VALOR();
int LLAMA();
int ARG();
int OTROARG();

// Prototipos de funciones útiles en el análisis sintáctico recursivo
char get_char();
int rechaza(char*);

// Variables globales útiles en el análisis sintáctico
int index_cadena = -1; // Indica el índice actual, que refiere al caracter c en revisión, de la cadena de átomos
char c; // Variable global que indica al caracter-átomo en curso

/*
    Función getchar para analizar a la cadena de átomos en la etapa de análisis
    sintáctico recursivo.
    Cada vez que se realiza una llamada se manda al caracter en curso de la cadena de átomos.
*/
char get_char(){
    index_cadena++; 
    char cc = cadena_atomos[index_cadena];
    //printf("CARACTER ACTUAL DE LA CADENA DE ÁTOMOS: %c\n",cc); 
    return cc;
}

/*
    Función de rechazo de cadena. Es una función que recibe como argumento a una cadena de caracteres que debe representar
    a los átomos que se esperaban cuando se presentó el rechazo. Es una función genérica presente en varias situaciones de rechazo
    Cada vez que se hace una llamada a la función, se realiza un incremento unitario en la variable global de errores sintácticos.
*/
int rechaza(char* sim_esperados){
    fprintf(Errores, "ERROR SINTÁCTICO: Átomo %c en índice %d, se esperaba %s\n", c, index_cadena, sim_esperados);
    errores_sintacticos++;
    return 0;
}

//########################### DEFINICIÓN DE LAS FUNCIONES RECURSIVAS ###################################
int PROGRAM(){
    if (c == 'b' || c == 'g' || c == '#' || c == 'y' || c == 'x'){ // prod 1, caso 4
        FUNC();
        OTRAFUNC();
        return 0;
    } else {
        // rechaza;
        rechaza("b g # y x");
        return 0;
    }
}

int OTRAFUNC(){
    if (c == 'b' || c == 'g' || c == '#' || c == 'y' || c == 'x'){ // prod 2, caso 4
        FUNC();
        OTRAFUNC();
        return 0;
    } else if (c == '\0') { // prod 3, caso 3  FIN DE CADENA
        //printf("Se encontró un fin de cadena en átomo: %d", index_cadena);
        return 0;
    } else {
        // rechaza
        rechaza("b g # y x \\0");
        return 0;
    }
}

int FUNC(){
    if (c == 'b' || c == 'g' || c == '#' || c == 'y' || c == 'x') { // PROD 4, CASO 4
        TIPO();
        if (c == 'i'){
            c = get_char();
        } else {
            // rechaza
            rechaza("i");
        }
        if (c == '('){
            c = get_char();
        } else {
            // rechaza
            rechaza("(");
        }
        PARAM();
        if (c == ')'){
            c = get_char();
        } else {
            // rechaza
            rechaza(")");
        }
        if (c == '{'){
            c = get_char();
        } else {
            // rechaza
            rechaza("{");
        }
        CUERPO();
        if (c == '}'){
            c = get_char();
        } else {
            // rechaza
            rechaza("}");
        }
        return 0;
    } else {
        // rechaza
        rechaza("b g # y x");
        return 0;
    }
}

int PARAM(){
    if (c == 'b' || c == 'g' || c == '#' || c == 'y' || c == 'x') { // prod 5, caso 4
        TIPO();
        if (c == 'i'){
            c = get_char();
        } else {
            rechaza("i");
            // rechaza
        }
        OTROPARAM();
        return 0;
    } else if (c == ')'){   // prod 6, caso 3
        return 0;
    } else {
        // rechaza
        rechaza("b g # y x )");
        return 0;
    }
}

int OTROPARAM(){
    if (c == ','){  // prod 7, caso 2
        c = get_char();
        TIPO();
        if (c == 'i'){
            c = get_char();
        } else {
            // rechaza;
            rechaza("i");
        }
        OTROPARAM();
        return 0;
    } else if (c == ')'){   // prod 8, caso 3
        return 0;
    } else {
        // rechaza
        rechaza(", )");
        return 0;
    }
}

int CUERPO(){
    if (c=='b'||c=='g'||c=='#'||c=='y'||c=='x'||c=='c'||c=='i'||c=='f'||c=='h'||c=='w'||c=='j'||c=='['||c=='z'||c=='}'){    // prod 9, caso 3
        DECL();
        LISTAP();
        return 0;
    } else {
        rechaza("b g # y x c i f h w j [ z }");
        // rechaza
        return 0;
    }
}

int DECL(){
    if (c=='c'||c=='i'||c=='f'||c=='h'||c=='w'||c=='j'||c=='['||c=='z'||c=='}'){
        return 0;
    } else if (c=='b'||c=='g'||c=='#'||c=='y'||c=='x'){
        D();
        DECL();
        return 0;
    } else {
        // rechaza
        rechaza("c i f h w j [ z } b g # y x");
        return 0;
    }
}

int D(){
    if (c=='b'||c=='g'||c=='#'||c=='y'||c=='x'){
        TIPO();
        K();
        if (c==';'){
            c=get_char();
        }else{
            //rechaza
            rechaza(";");
        }
        return 0;
    }else{
        rechaza("b g # y x");
        //rechaza
        return 0;
    }
}

int TIPO(){
    if (c=='b'){
        c=get_char();
        return 0;
    } else if (c=='g'){
        c=get_char();
        return 0;
    } else if (c=='#'){
        c=get_char();
        return 0;
    } else if (c=='y'){
        c=get_char();
        return 0;
    } else if (c=='x'){
        c=get_char();
        return 0;
    } else {
        //rechaza
        rechaza("b g # y x");
        return 0;
    }
}

int K(){
    if (c=='i'){
        c = get_char();
        Q();
        return 0;
    } else {
        // rechaza
        rechaza("i");
        return 0;
    }
}

int Q(){
    if (c==';'){
        return 0;
    } else if (c=='='){
        c = get_char();
        N();
        C();
        return 0;
    } else if (c==','){
        c = get_char();
        K();
        return 0;
    } else {
        //rechaza
        rechaza("; = ,");
        return 0;
    }
}

int N(){
    if (c=='n'){    // prod 22
        c=get_char();
        return 0;
    } else if (c=='r') {    // prod 23
        c=get_char();
        return 0;
    } else if (c=='s'){ // prod 24
        c=get_char();
        return 0;
    } else {
        // rechaza;
        rechaza("n r");
        return 0;
    }
}

int C(){
    if (c==';'){    // prod 25
        return 0;
    } else if (c == ','){   // prod26
        c = get_char();
        K();
        return 0;
    } else {
        //rechaza
        rechaza("; ,");
        return 0;
    }
}

int A(){
    if (c=='i'){
        c = get_char();
        if (c == '='){
            c = get_char();
        } else {
            //rechaza
            rechaza("=");
        }
        APRIMA();
        if (c==';'){
            c=get_char();
        } else {
            //rechaza
            rechaza(";");
        }
        return 0;
    } else {
        //rechaza
        rechaza("i");
        return 0;
    }
}

int APRIMA(){
    if (c=='s'){
        c=get_char();
        return 0;
    } else if (c=='('||c=='i'||c=='n'||c=='r'||c=='['){
        E();
        return 0;
    } else {
        //rechaza
        rechaza("s ( i n r [");
        return 0;
    }
}

int E(){
    if (c=='('||c=='i'||c=='n'||c=='r'||c=='['){
        T();
        EPRIMA();
        return 0;
    } else {
        //rechaza
        rechaza("( i n r [");
        return 0;
    }
}

int EPRIMA(){
    if (c == '+'){
        c = get_char();
        T();
        EPRIMA();
        return 0;
    } else if (c == '-'){
        c = get_char();
        T();
        EPRIMA();
        return 0;
    } else if (c == ')' || c == ';'){
        return 0;
    } else {
        //rechaza
        rechaza("+ - ) ;");
        return 0;
    }
}

int T(){
    if (c=='('||c=='i'||c=='n'||c=='r'||c=='['){
        F();
        TPRIMA();
        return 0;
    } else {
        // rechaza
        rechaza("( i n r [");
        return 0;
    }
}

int TPRIMA(){
    if (c == '*'){
        c = get_char();
        F();
        TPRIMA();
        return 0;
    } else if (c == '/') {
        c = get_char();
        F();
        TPRIMA();
        return 0;
    }  else if (c == '\\') {
        c = get_char();
        F();
        TPRIMA();
        return 0;
    }  else if (c == '%') {
        c = get_char();
        F();
        TPRIMA();
        return 0;
    } else if (c == '^') {
        c = get_char();
        F();
        TPRIMA();
        return 0;
    } else if (c=='+'||c=='-'||c==')'||c==';'){
        return 0;
    } else {
        //rechaza
        rechaza("* / \\ % ^ + - ) ;");
        return 0;
    }
}

int F(){
    if (c == '('){
        c = get_char();
        E();
        if (c==')'){
            c = get_char();
        } else {
            // rechaza
            rechaza(")");
        }
        return 0;
    } else if (c == 'i'){
        c = get_char();
        return 0;
    } else if (c == 'n'){
        c = get_char();
        return 0;
    } else if (c == 'r'){
        c = get_char();
        return 0;
    } else if (c == '['){
        LLAMA();
        return 0;
    } else {
        // rechaza
        rechaza("( i n r [");
        return 0;
    }
}

int R(){
    if (c == 'i'){
        c = get_char();
        RPRIMA();
        V();
        return 0;
    } else if (c == 'n'){
        c = get_char();
        RPRIMA();
        VPRIMA();
        return 0;
    } else if (c == 'r'){
        c = get_char();
        RPRIMA();
        VPRIMA2();
        return 0;
    } else if (c == 's') {
        RPRIMA();
        VPRIMA3();
        return 0;
    } else {
        //rechaza
        rechaza("i n r s");
        return 0;
    }
}

int RPRIMA(){
    if (c=='>'){
        c = get_char();
        return 0;
    } else if (c == '<'){
        c = get_char();
        return 0; 
    } else if (c == 'l'){
        c = get_char();
        return 0; 
    } else if (c == 'e'){
        c = get_char();
        return 0; 
    } else if (c == 'd'){
        c = get_char();
        return 0; 
    } else if (c == 'u'){
        c = get_char();
        return 0; 
    } else {
        //rechaza
        rechaza("> < l e d u");
        return 0;
    }
}

int V(){
    if (c=='i') {
        c = get_char();
        return 0;
    } else if (c == 'n'){
        c = get_char();
        return 0;
    } else if (c == 'r'){
        c = get_char();
        return 0;
    } else if (c == 's'){
        c = get_char();
        return 0;
    } else {
        //rechaza
        rechaza("i n r s");
        return 0;
    }
}

int VPRIMA(){
    if (c == 'n'){
        c = get_char();
        return 0;
    } else if (c == 'i'){
        c = get_char();
        return 0;
    } else {
        //rechaza
        rechaza("n i");
        return 0;
    }
}

int VPRIMA2(){
    if (c == 'r'){
        c = get_char();
        return 0;
    } else if (c == 'i') {
        c = get_char();
        return 0;
    } else {
        // rechaza
        rechaza("r i");
        return 0;
    }
}

int VPRIMA3(){
    if (c == 's') {
        c = get_char();
        return 0;
    } else if (c == 'i') {
        c == get_char();
        return 0;
    } else {
        // rechaza
        rechaza("s i");
        return 0;
    }
}

int P(){
    if (c == 'i'){
        A();
        return 0;
    } else if (c == 'f'){
        I();
        return 0;
    } else if (c == 'h'){
        H();
        return 0;
    } else if (c == 'w'){
        W();
        return 0;
    } else if (c == 'j'){
        J();
        return 0;
    } else if (c == '['){
        LLAMA();
        return 0;
    } else if (c == 'z'){
        DEVUELVE();
        return 0;
    } else if (c == 'c'){
        c = get_char();
        if (c == ';'){
            c = get_char();
        } else {
            //rechaza
            rechaza(";");
        }
        return 0;
    } else {
        //rechaza
        rechaza("i f h w j [ z c");
        return 0;
    }
}

int LISTAP(){
    if (c=='}'||c=='t'||c==':'||c=='q'||c=='a'||c=='o'){
        return 0;
    } else if (c=='c'||c=='i'||c=='f'||c=='h'||c=='w'||c=='j'||c=='['||c=='z'){
        P();
        LISTAP();
        return 0;
    } else {
        //rechaza
        rechaza("} t : q a o c i f h w j [ z");
        return 0;
    }
}

int W(){
    if (c=='w'){
        c = get_char();
        if (c=='('){
            c=get_char();
        } else {
            //rechaza
            rechaza("(");
        }
        R();
        if (c==')'){
            c=get_char();
        } else {
            //rechaza
            rechaza(")");
        }
        if (c=='m'){
            c=get_char();
        } else {
            //rechaza
            rechaza("m");
        }
        if (c=='{'){
            c = get_char();
        } else {
            //rechaza
            rechaza("{");
        }
        LISTAP();
        if (c =='}'){
            c = get_char();
        } else {
            //rechaza
            rechaza("}");
        }
        return 0;
    } else {
        //rechaza
        rechaza("w");
        return 0;
    }
}

int I(){
    if (c=='f'){
        c = get_char();
        if (c=='('){
            c=get_char();
        } else {
            //rechaza
            rechaza("(");
        }
        R();
        if (c==')'){
            c=get_char();
        } else {
            //rechaza
            rechaza(")");
        }
        LISTAP();
        IPRIMA();
        if (c==':'){
            c=get_char();
        } else {
            //rechaza
            rechaza(":");
        }
        return 0;
    } else {
        //rechza
        rechaza("f");
        return 0;
    }
}

int IPRIMA(){
    if (c=='t'){
        c = get_char();
        LISTAP();
        return 0;
    } else if (c == ':'){
        return 0;
    } else {
        //rechaza
        rechaza("t :");
        return 0;
    }
}

int J(){
    if (c=='j'){
        c=get_char();
        if (c=='('){
            c = get_char();
        } else {
            //rechaza
            rechaza("(");
        }
        Y();
        X();
        Z();
        if (c=='{'){
            c=get_char();
        } else {
            //rechaza
            rechaza("{");
        }
        LISTAP();
        if (c=='}'){
            c=get_char();
        } else {
            //rechaza
            rechaza("}");
        }
        return 0;
    } else {
        //rechaza
        rechaza("j");
        return 0;
    }
}

int Y(){
    if (c=='i'){
        c=get_char();
        if (c=='='){
            c=get_char();
        } else {
            //rechaza
            rechaza("=");
        }
        E();
        if (c==';'){
            c=get_char();
        } else {
            //rechaza
            rechaza(";");
        }
        return 0;
    } else if (c == ';'){
        c = get_char();
        return 0;
    } else {
        //rechaza
        rechaza("i ;");
        return 0;
    }
}

int X(){
    if (c=='i'||c=='n'||c=='r'||c=='s'){
        R();
        if (c==';'){
            c=get_char();
        } else {
            //rechaza
            rechaza(";");
        }
        return 0;
    } else if (c == ';'){
        c = get_char();
        return 0;
    } else {
        //rechaza
        rechaza("i n r s ;");
        return 0;
    }
}

int Z(){
    if (c=='i'){
        c = get_char();
        if (c=='='){
            c=get_char();
        } else {
            //rechaza
            rechaza("=");
        }
        E();
        if (c==')'){
            c=get_char();
        } else {
            //rechaza
            rechaza(")");
        }
        return 0;
    } else if (c==')'){
        c = get_char();
        return 0;
    } else {
        //rechaza
        rechaza("i )");
        return 0;
    }
}

int H(){
    if (c == 'h'){
        c = get_char();
        if (c=='('){
            c=get_char();
        } else {
            //rechaza
            rechaza("(");
        }
        if (c=='i'){
            c=get_char();
        } else {
            //rechaza
            rechaza("i");
        }
        if (c==')'){
            c=get_char();
        } else {
            //rechaza
            rechaza(")");
        }
        if (c=='{'){
            c=get_char();
        } else {
            //rechaza
            rechaza("{");
        }
        CPRIMA();
        OPRIMA();
        if (c=='}'){
            c=get_char();
        } else {
            //rechaza
            rechaza("}");
        }
        return 0;
    } else {
        //rechaza
        rechaza("h");
        return 0;
    }
}

int CPRIMA(){
    if (c == 'a'){
        c = get_char();
        if (c=='n'){
            c=get_char();
        } else {
            //rechaza
            rechaza("n");
        }
        if (c==':'){
            c=get_char();
        } else {
            //rechaza
            rechaza(":");
        }
        LISTAP();
        U();
        CPRIMA();
        return 0;
    } else if (c == 'o' || c == '}'){
        return 0;
    } else {
        //rechaza
        rechaza("a o }");
        return 0;
    }
}

int OPRIMA(){
    if (c == 'o'){
        c = get_char();
        if (c==':'){
            c=get_char();
        } else {
            //rechaza
            rechaza(":");
        }
        LISTAP();
        return 0;
    } else if (c == '}'){
        return 0;
    } else {
        //rechaza
        rechaza("o }");
        return 0;
    }
}

int U(){
    if (c == 'q'){
        c = get_char();
        return 0;
    } else if (c == 'a' || c == 'o' || c == '}'){
        return 0;
    } else {
        //rechaza
        rechaza("q a o }");
        return 0;
    }
}

int DEVUELVE(){
    if (c == 'z') {
        c = get_char();
        if (c=='('){
            c=get_char();
        } else {
            //rechaza
            rechaza("(");
        }
        VALOR();
        if (c==')'){
            c=get_char();
        } else {
            //rechaza
            rechaza(")");
        }
        if (c==';'){
            c=get_char();
        } else {
            //rechaza
            rechaza(";");
        }
        return 0;
    } else {
        //rechaza
        rechaza("z");
        return 0;
    }
}

int VALOR(){
    if (c=='i'||c=='n'||c=='r'||c=='s'){
        V();
        return 0;
    } else if (c == ')'){
        return 0;
    } else {
        //rechaza
        rechaza("i n r s )");
        return 0;
    }
}

int LLAMA(){
    if (c == '['){
        c = get_char();
        if (c=='i'){
            c=get_char();
        } else {
            //rechaza
            rechaza("i");
        }
        if (c=='('){
            c=get_char();
        } else {
            //rechaza
            rechaza("(");
        }
        ARG();
        if (c==')'){
            c=get_char();
        } else {
            //rechaza
            rechaza(")");
        }
        if (c==']'){
            c=get_char();
        } else {
            //rechaza
            rechaza("]");
        }
        return 0;
    } else {
        //rechaza
        rechaza("[");
        return 0;
    }
}

int ARG(){
    if (c == ')'){
        return 0;
    } else if (c == 'i'||c=='n'||c=='r'||c=='s'){
        V();
        OTROARG();
        return 0;
    } else {
        //rechaza
        rechaza(") i n r s");
        return 0;
    }
}

int OTROARG(){
    if (c == ','){
        c = get_char();
        V();
        OTROARG();
        return 0;
    } else if (c == ')'){
        return 0;
    } else {
        //rechaza
        rechaza(", )");
        return 0;
    }
}

int main(int argc, char* argv[]){
    yyin = fopen(argv[1], "r"); // Se recibe al archivo de interés con componentes léxicos
    if (yyin!=NULL){
        // Se crean los archivos y se realizan escrituras utiles
        Tokens = fopen("Tokens.txt", "w");  // Archivo para TOKENS
        fprintf(Tokens, "TOKENS\nCLASE\tVALOR\n");
        LiteralesReales = fopen("TablaLiteralesReales.txt", "w");  // Archivo para tabla de literales reales
        fprintf(LiteralesReales, "TABLA DE LITERALES REALES (CLASE 3)\nPOSICION\tDATO\n");
        LiteralesCadenas = fopen("TablaLiteralesCadenas.txt", "w");    // Archivo para tabla de literales cadenas
        fprintf(LiteralesCadenas, "TABLA DE LITERALES CADENAS (CLASE 4)\nPOSICION\tDATO\n");
        Simbolos = fopen("TablaSimbolos.txt", "w");    // Archivo para tabla de simbolos
        fprintf(Simbolos, "TABLAS DE SIMBOLOS (CLASE 1)\nPOSICION\tNOMBRE DEL IDENTIFICADOR\tTIPO\n");
        Errores = fopen("Errores.txt", "w");    // Archivo para errores léxico-sintácticos
        fprintf(Errores, "ERRORES LÉXICOS Y SINTÁCTICOS\n");
        Atomos = fopen("CadenaAtomos.txt", "w");    // Archivo para imprimir a la cadena de átomos
        fprintf(Atomos, "CADENA DE ATOMOS\nINDICE\tATOMOS\n");

        yylex();    // ETAPA: Análisis léxico

        // Se genera la cadena de átomos
        cadena_atomos = generar_cadena_atomos(head_atomos);
        fprintf(Atomos, "\nCadena de atomos lineal: %s\n", cadena_atomos);
        c = get_char(); // Se obtiene al primer caracter de la cadena de átomos para comenzar con el análisis sintáctico recursivo
        PROGRAM();  // ETAPA: Análisis sintáctico recursivo

        // Una vez que concluye la lectura del archivo y se llenan las tablas, se añade la info. en los archivos
        write_tablit(LiteralesReales,head_Real);
        write_tablit(LiteralesCadenas,head_Cadenas);
        write_tabsim(Simbolos,head_tabsim);

        // Se escriben en el archivo de errores léxicos-sintácticos las conclusiones sobre errores
        if (errores_lexicos == 0){
            fprintf(Errores, "El programa fuente no tiene errores léxicos\n");
        }
        if (errores_sintacticos == 0){
            fprintf(Errores, "El programa fuente no tiene errores sintácticos\n");
        }
        if (errores_lexicos + errores_sintacticos == 0){
            fprintf(Errores, "Compilación exitosa, el programa es léxica y sintácticamente correcto\n");
        }

        // Cierra escritura de archivos para guardar archivos en texto
        fclose(Tokens);
        fclose(LiteralesReales);
        fclose(LiteralesCadenas);
        fclose(Simbolos);
        fclose(Errores);
        fclose(Atomos);

        // Lectura de archivos para imprimir contenido en pantalla
        Tokens = fopen("Tokens.txt", "r");  // Archivo para TOKENS
        LiteralesReales = fopen("TablaLiteralesReales.txt", "r");  // Archivo para tabla de literales reales
        LiteralesCadenas = fopen("TablaLiteralesCadenas.txt", "r");    // Archivo para tabla de literales cadenas
        Simbolos = fopen("TablaSimbolos.txt", "r");    // Archivo para tabla de simbolos
        Errores = fopen("Errores.txt", "r");
        Atomos = fopen("CadenaAtomos.txt", "r");
        read_file(Simbolos);
        read_file(LiteralesReales);
        read_file(LiteralesCadenas);
        read_file(Tokens);
        read_file(Atomos);
        read_file(Errores);
        
        // Se cierra la lectura de archivos 
        fclose(Tokens);
        fclose(LiteralesReales);
        fclose(LiteralesCadenas);
        fclose(Simbolos);
        fclose(Errores);
        fclose(Atomos);
        printf("\n");
    } else {
        printf("No existe el programa fuente argumentado o no se argumentó algún archivo.\n");
    }
    return 0;
}
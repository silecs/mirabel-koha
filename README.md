Webservice Mir@bel pour Koha
============================

Documentation 
v.1 Juin 2011 - v2. Mars 2014


Objet du script
---------------

Le webservice interroge le service REST de Mir@bel, insère et met à jour les
champs Koha correspondant aux différents services dans les notices
bibliographiques ; il permet également l'effacement des champs des notices
lorsque les services sont supprimés de
[Mir@bel](http://www.reseau-mirabel.info/).

Ce script met à jour des champs d'une notice existante, et ne crée pas de
notices bibliographiques ; les biblionumber de Koha (identifiant des notices)
doivent être saisis dans Mir@bel.  Les champs et sous-champs doivent être
préalablement définis dans la grille de catalogage afin que l'information
ajoutée soit visible.

Pour des informations sur Mi@bel : <http://www.reseau-mirabel.info/>

Le service REST de Mir@bel n'est accessible qu'à partir d'adresses IP déclarées auprès des administrateurs de Mir@bel.
Par conséquent le script ne fonctionnera qu'à partir de ces IP.

### Installation

Ce script est librement accessible sur <https://github.com/silecs/mirabel-koha>.

La version initiale du script est disponible sur le dépôt git de BibLibre : 
<http://git.biblibre.com/?p=mirabel;a=summary>

Le script peut être installé dans /home/koha par exemple, en fonction de votre installation.


Configuration
-------------

### properdata.txt

`properdata.txt` indique la correspondance entre les types d'accès en ligne renvoyés par le service REST et les types de services utilisés dans le script (sans espace ni caractère accentué) (ce fichier ne devrait pas être modifié)

```
Intégral;texteint 
Sommaire;som 
Indexation;index 
Résumé;resum 
```

### config.yml

`config.yml` paramètre la correspondance entre les balises XML fournies par le service REST et les champs et sous-champs Koha.
Vous devez au préalable définir ces zones Marc dans vos grilles Marc,
un champ par type de service : texte intégral, sommaire, résumé et indexation.

#### Exemple commenté de config.yml

```yml
# URL d'accès au webservice de Mir@bel
base_url: 'http://www.reseau-mirabel.info/site/service'
#
# Configuration pour l'ajout et la modification
update:
    # Type d'accès (cf properdata.txt pour la liste des types)
    texteint:
        field: 857
        # Les clés seront les noms des attributs de Koha pour ce champ (857.a etc).
        # Les valeurs peuvent être :
        #
        #  * un champ du webservice Mir@bel ("acces")
        #  * alternative ("urldirecte|urlservice" : si "urldirecte" est vide, alors "urlservice")
        #  * concaténation ("debut fin" : champs "debut" concaténé avec "fin" via un espace de séparation)
        #  * concaténation par un filtre "periode" ou "dates" ("debut fin :(periode)" appliquera le filtre "periode" aux 2 dates)
        #
        a: "urldirecte|urlservice"
        b: "nom"
        c: "acces"
        d: "debut fin :(periode)"
        e: "couverture"
        3: "id"
    som:
        field: 388
        a: "urldirecte|urlservice"
        b: "nom"
        c: "acces"
        d: "debut fin :(periode)"
        e: "couverture"
        3: "id"
```

Les champs disponibles sont ceux du webservice Mir@bel :

* id
* nom
* acces
* type
* couverture
* lacunaire
* selection
* urlservice
* urldirecte
* debut
* fin

**Attention à la syntaxe dans le fichier yml**, les espaces ont de l'importance ; ne pas mettre de tabulation à la place d'un espace.

L'URL du service REST de Mir@bel est en première ligne de `config.yml`.


Exécution du script
-------------------

Le script est exécuté avec les options en fonction des services à importer ou mettre à jour : 

```
perl mirabel_to_koha.pl [options]

    --help          -h
    --man

    --partenaire=   -p   Identifiant numérique du partenaire
    --issn=         -s   ISSN
    --issnl=        -l   ISSNl
    --issne=        -e   ISSNe
    --type=         -t   Type, parmi (texte ; sommaire ; resume ; indexation ; tout)
    --acces=        -a   Accès, parmi (libre ; restreint ; tout)
    --all
    --pas-lacunaire      Exclut les accès lacunaires (certains numéros manquent)
    --pas-selection      Exclut les accès sélections (certains articles manquent)
    --revue=             Seulement les accès de la revue : liste d'ID séparés par ","
    --ressource=    -r   Seulement les accès de la ressource : liste d'ID séparés par ","
    --collection=   -c   Seulement les accès de la collection : liste d'ID séparés par ","
    --mesressources      Seulement pour les ressources suivies par ce partenaire

    --simulation
    --config=
    --config-koha=
```

### Chemins et fichiers

Par défaut, le script suppose que la configuration de Koha contient un paramètre "mirabel" avec le chemin vers la configuration.
Si ce n'est pas le cas, il faut passer le paramètre `--config`.
Par exemple, pour indiquer qu'il faut utiliser la configuration du répertoire /home/koha/mirabel :
`./mirabel_to_koha.pl --config=/home/koha/mirabel`.

Par ailleurs, le script utilise les bibliothèques Perl fournies par Koha.
Pour les rendre accessibles, il est recommander d'ajouter à `~/.profile` une ligne :

    export PERL5LIB="/home/koha/mon-instance-koha/lib"

Le répertoire ci dessus contient notamment un sous-répertoire "C4/".


### Exemple

Pour mettre à jour Koha avec tous les accès (libre + restreints, tous types) du partenaire d'identifiant 2 :

```sh
# syntaxe étendue
perl mirabel_to_koha.pl --partenaire=2 --type=tout --acces=tout
 
# syntaxe brève
./mirabel_to_koha.pl -p 2 -t tout -a tout
```


Services supprimés
------------------

Le script `delete_services.pl` permet de supprimer les champs correspondant aux services supprimés dans Mir@bel.

Lancé sans option, il interroge l'url <http://www.reseau-mirabel.info/site/service?suppr> et supprime les champs correspondants aux services supprimés depuis 24 heures, en se basant sur l'identifiant du service.

On peut également forcer la suppression de tous les champs alimentés par Mir@bel.

Sa documentation détaillée est consultable par la commande `perl delete_services.pl --man`.

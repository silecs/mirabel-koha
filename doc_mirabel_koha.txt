Webservice Mir@bel pour Koha
Documentation
Juin 2011

=======================
Objet du script
=======================

Le webservice interroge le service REST de Mir@bel, insère et met à jour les champs Koha correspondants aux différents services dans les notices bibliographiques ; il permet également l'effacement des champs des notices lorsque les services sont supprimés de Mir@bel.
Ce script met à jour des champs d'une notice existante, et ne crée pas de notices bibliographiques ; les biblionumber de Koha (identifiant des notices) doivent être saisis dans Mir@bel. Les champs et sous-champs doivent être préalablement définis dans la grille de catalogage afin que l'information ajoutée soit visible.

Pour information sur Mi@bel : http://www.reseau-mirabel.info/
Le service REST de Mir@bel n'est accessible qu'à partir d'adresses ip déclarées auprès des administrateur de Mir@bel. Par conséquent le script ne fonctionnera qu'à partir de ces ip.
 Installation

Le script est disponible sur le dépôt git de BibLibre : 
http://git.biblibre.com/?p=mirabel;a=summary

Le script peut être installé dans /home/koha par exemple, en fonction de votre installation.

=======================
Configuration
=======================

*** properdata.txt : indique la correspondance entre les types de services renvoyés par le service REST et les types de services utilisés dans le script (sans espace ni caractère accentué) (ce fichier ne devrait pas être modifié)

Texte Intégral;texteint 
Sommaire;som 
Indexation;index 
Résumé;resum 

*** config.yml : paramétrage de la correspondance entre les balises xml fournies par le service REST et les champs et sous-champs Koha ; un champ par type de service.

texteint: 
    field : 857 
    a: "urldirecte|urlservice" 
    b: "nom" 
    c: "acces" 
    d: "debut fin" 
    e: "couverture" 
    3: "id" 
som: 
    field: 388 
    a: "urldirecte|urlservice" 
    b: "nom" 
    c: "acces" 
    d: "debut fin" 
    e: "couverture" 
    3: "id" 

(Attention à la syntaxe dans le fichier yml, les espaces ont de l'importance ; ne pas mettre de tabulation à la place d'un espace)

=======================
Exécution du script
=======================

Attention l'url du service REST de Mir@bel est écrite en dur dans le script, ligne
my $url = "http://www.reseau-mirabel.info/rest.php?";

Le script est exécuté avec les options en fonction des services à importer ou mettre à jour : 

perl mirabel_to_koha.pl

-i identifiant du partenaire
-n issn
-l issnl
-e issne
-t type (texte ; sommaire ; resume ; indexation ; tout)
-a accès (libre ; restreint ; tout)
-c couverture (exhaustif ; non_occasionnel)
-all 


=======================
Services supprimés
=======================

Le script delete_services.pl permet de supprimer les champs correspondant aux services supprimés dans Mir@bel.
Lancé sans option, il interroge l'url : http://www.reseau-mirabel.info/rest.php?suppr et supprime les champs correspondants aux services en se basant sur l'identifiant du service.


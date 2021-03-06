### Application empirique double selection: Niveau de diplôme et salaire, enquête emploi
### Jérémy L'Hour
### 29/05/2020

rm(list=ls())

### CHARGEMENT DES PACKAGES
#library('aws.s3')
library('haven')
library('glmnet')
library('ggplot2')
library('fastDummies') # pour créer des dummies à partir de catégories
library('caret') # pour utiliser la fonction qui repère les variables colinéaires
library('foreach') # utile pour calculer les ecarts-types clusterisés
library('doParallel')
# library('grplasso') # pour group-lasso, mais solution hyper longue

#setwd("/home/zctxti")
setwd("/Users/jeremylhour/Documents/code")

### Fonctions faites maison
source('grandedim/functions/group_lasso.R') # Algorithme de calcul du group lasso, plus rapide que le package ici
source('grandedim/functions/K_matrix_cluster.R') # Cluster standard errors


####################
####################
### DATA LOADING ###
####################
####################
#data = read_sas("/Users/jeremylhour/Documents/data/indiv171.sas7bdat")

bucket = "groupe-1006"
files = get_bucket(bucket = bucket, prefix = "grandedim/")

for(file in files[2:13]){
  path = file$Key
  save_object(bucket = bucket,  prefix = "grandedim/", object=path,file=path)
}

### 2017
data_171 = read_sas("grandedim/indiv171.sas7bdat")
data_171 = as.data.frame(data_171)

data_172 = read_sas("grandedim/indiv172.sas7bdat")
data_172 = as.data.frame(data_172)

data_173 = read_sas("grandedim/indiv173.sas7bdat")
data_173 = as.data.frame(data_173)

data_174 = read_sas("grandedim/indiv174.sas7bdat")
data_174 = as.data.frame(data_174)

data_17 = rbind(data_171,data_172,data_173,data_174)
remove(data_171,data_172,data_173,data_174)


### 2018
data_181 = read_sas("grandedim/indiv181.sas7bdat")
data_181 = as.data.frame(data_181)

data_182 = read_sas("grandedim/indiv182.sas7bdat")
data_182 = as.data.frame(data_182)

data_183 = read_sas("grandedim/indiv183.sas7bdat")
data_183 = as.data.frame(data_183)

data_184 = read_sas("grandedim/indiv184.sas7bdat")
data_184 = as.data.frame(data_184)

data_18 = rbind(data_181,data_182,data_183,data_184)
remove(data_181,data_182,data_183,data_184)

### 2019
data_191 = read_sas("grandedim/indiv191.sas7bdat")
data_191 = as.data.frame(data_191)

data_192 = read_sas("grandedim/indiv192.sas7bdat")
data_192 = as.data.frame(data_192)

data_193 = read_sas("grandedim/indiv193.sas7bdat")
data_193 = as.data.frame(data_193)

data_194 = read_sas("grandedim/indiv194.sas7bdat")
data_194 = as.data.frame(data_194)

data_19 = rbind(data_191,data_192,data_193,data_194)
remove(data_191,data_192,data_193,data_194)

### Certaines variables ne sont pas dans toutes les tables:
common_var = intersect(intersect(names(data_17), names(data_18)),names(data_19))
data = rbind(data_17[,common_var],data_18[,common_var],data_19[,common_var])
remove(data_17,data_18,data_19)

#######################
#######################
### DATA MANAGEMENT ###
#######################
#######################

# Outcome "Y", log du salaire mensuel net
data[,"SALRED"] = as.numeric(data[,"SALRED"]) # salaire mensuel net
data[,"LOG_SAL"] = log(data[,"SALRED"]) # log salaire

# Variable d'intérêt, "X_1", en facteurs à plusieurs niveaux
data[,"DIP"] = ifelse(data[,"DIP"]=="",NA,data[,"DIP"])
data[,"DIP"] = as.factor(data[,"DIP"]) # niveau de diplome le plus eleve

# Poids de sondage
data[,"EXTRIDF"] = as.numeric(data[,"EXTRIDF"]) # poids de sondages

# Autres variables "X_2"
# 1. Continues
data[,"AG"] = as.numeric(data[,"AG"]) # Age
data[,"AG_2"] = data[,"AG"]^2 # Age au carré
data[,"ANCENTR"] = as.numeric(data[,"ANCENTR"]) # Ancienneté dans l'entreprise
data[,"HHC"] = as.numeric(data[,"HHC"]) # Nombre d'heures travaillées en moyenne
data[,"NBENFIND"] = as.numeric(data[,"NBENFIND"]) # Nombre d'enfants de l'individu

names_continuous = c("AG", "AG_2", "ANCENTR","HHC","NBENFIND")

# 2. Variables categorielles
data[,"SEXE"] = as.factor(data[,"SEXE"]) # Sexe
data[,"APPDIP"] = as.factor(data[,"APPDIP"]) # diplôme obtenu en apprentissage
data[,"SANTGEN"] = as.factor(data[,"SANTGEN"]) # niveau de santé perçu
data[,"ADMHAND"] = as.factor(data[,"ADMHAND"]) # reconnaissance d'un handicap
data[,"CATAU2010"] = as.factor(data[,"CATAU2010"]) # categorie de la commune du logement de residence
data[,"CHPUB"] = as.factor(data[,"CHPUB"]) # nature de l'employeur dans profession principale
data[,"CHRON"] = as.factor(data[,"CHRON"]) # maladie chronique
data[,"COMSAL"] = as.factor(data[,"COMSAL"]) # mode d'entrée dans l'emploi actuel
data[,"COURED"] = as.factor(data[,"COURED"]) # en couple
data[,"CSPM"] = as.factor(data[,"CSPM"]) # CSP Mere
data[,"CSPP"] = as.factor(data[,"CSPP"]) # CSP Pere
data[,"FORDAT"] = as.factor(data[,"FORDAT"]) # annee de fin d'études initiales
data[,"DESC"] = as.factor(data[,"DESC"]) # descendance d'immigrés
data[,"IMMI"] = as.factor(data[,"IMMI"]) # immigre
data[,"DUHAB"] = as.factor(data[,"DUHAB"]) # type d'horaires de travail
data[,"ENFRED"] = as.factor(data[,"ENFRED"]) # au moins un enfant dans le menage
data[,"SPE"] = as.factor(data[,"SPE"]) # champs des études suivies (e.g. science, lettre education)
data[,"MAISOC"] = as.factor(data[,"MAISOC"]) # teletravail
data[,"MATRI"] = as.factor(data[,"MATRI"]) # statut matrimonial
data[,"NAT14"] = as.factor(data[,"NAT14"]) # nationalité
data[,"NBAGEENFA"] = as.factor(data[,"NBAGEENFA"]) # nombre et age des enfants
data[,"NBENFA1"] = as.factor(data[,"NBENFA1"]) # nombre d'enfants de moins de 1 an
data[,"NBENFA10"] = as.factor(data[,"NBENFA10"]) # nombre d'enfants de moins de 10 ans
data[,"NBENFA15"] = as.factor(data[,"NBENFA15"]) # nombre d'enfants de moins de 15 ans
data[,"NBENFA18"] = as.factor(data[,"NBENFA18"]) # nombre d'enfants de moins de 18 ans
data[,"QP"] = as.factor(data[,"QP"]) # appartient à un quartier prioritaire
data[,"REG"] = as.factor(data[,"REG"]) # region du logement de résidence
data[,"SO"] = as.factor(data[,"SO"]) # statut d'occupation du logement
data[,"SOIRC"] = as.factor(data[,"SOIRC"]) # travaille le soir
data[,"TYPMEN21"] = as.factor(data[,"TYPMEN21"]) # type de ménage

names_categorical = c("SEXE","APPDIP","SANTGEN","ADMHAND","CATAU2010", "CHPUB","CHRON",
                      "COMSAL","COURED","CSPM","CSPP","FORDAT","DESC","IMMI","DUHAB","ENFRED","SPE",
                      "MAISOC","MATRI","NAT14","NBAGEENFA","NBENFA1","NBENFA10","NBENFA15","NBENFA18","QP","REG","SO","SOIRC","TYPMEN21")

### Mise en place des bonnes matrices
outcome = "LOG_SAL"
X_1_names = "DIP"
X_2_names = c(names_continuous,names_categorical)

data_use = data[complete.cases(data[,c(outcome,X_1_names,X_2_names)]),]
#save(data_use,file="data_use.Rda")
#put_object(file="data_use.Rda", object="grandedim/data_use.Rda", bucket=bucket)
#bucket = "groupe-1006"
#files = get_bucket(bucket = bucket, prefix = "grandedim/")
#path = files[3]$Contents$Key
#save_object(bucket = bucket,  prefix = "grandedim/", object=path,file=path)
#load("grandedim/data_use.Rda")
load("/Users/jeremylhour/Documents/data/data_use.Rda")

# "Y" (outcome)
Y = data_use[,outcome]

# "X_1" (variables d'intérêt)
X_1 = model.matrix(~. - 1, data = data.frame("EDUC"=as.factor(data_use[,X_1_names])), contrasts.arg = "EDUC")
X_1 = X_1[,1:(ncol(X_1)-1)] # On enlève la modalité "sans diplôme" pour éviter les problèmes de colinéarité.

# "X_2" (contrôles)
one_hot_category = dummy_cols(data_use[,names_categorical], remove_most_frequent_dummy=TRUE, remove_selected_columns=TRUE) # on transforme les variables catégorielles en variables binaires
X_2 = as.matrix(cbind(data_use[, names_continuous], one_hot_category))
X_2 = X_2[,!duplicated(t(X_2))] # On enlève les colonnes dupliquées
colinear = caret::findLinearCombos(cbind(X_1,X_2,rep(1,nrow(X_2)))) 
suppr = colinear$remove-ncol(X_1) # recalage par rapport à l'indice de X_2
X_2 = X_2[,-suppr] # On enlève les colonnes qui créent de la multicolinéairité, avec l'inclusion de X_1 et une constante

# Identifiants clustering menage / individus
ID_menage = data_use[,"IDENT"] # Identifiant du ménage, pour cluster dans les écart-types.
ID_indiv = paste(data_use[,"IDENT"],data_use[,"NOI"],sep="_") # Identifiant individu.

# Identifiant departement -- pour tester
ID_dep = data_use[,"DEP"]

coef_names = paste("X_1",colnames(X_1),sep="")
n = nrow(X_2); p = ncol(X_2)

remove(data, data_use, one_hot_category)


#################################################
#################################################
### ETAPE 0: Régressions simples et complètes ###
#################################################
#################################################

### Régression simple
reg_simple = lm(Y ~ X_1)
tau_simple = reg_simple$coefficients[coef_names]

### Régression complète
reg_full = lm(Y ~ X_1 + X_2)
tau_full = reg_full$coefficients[coef_names]
sigma_full = summary(reg_full)$coefficients[coef_names, 2]

### Calcul des écart-types clusterisés -- niveau menage
X_2_tilde = cbind(X_2,rep(1,nrow(X_2))) # On ajoute la constante pour faire la régression partielle
FS_residuals = X_1 - X_2_tilde%*%solve(t(X_2_tilde)%*%X_2_tilde)%*%(t(X_2_tilde) %*% X_1)

K_matrix_full = K_matrix_cluster(eps=sweep(FS_residuals,MARGIN=1,reg_full$residuals,`*`), cluster_var=ID_menage, df_adj=ncol(X_2)+ncol(X_1)+1) # cluster au niveau du ménage
J_matrix_full = t(FS_residuals)%*%FS_residuals / n
sigma_full_cluster = solve(J_matrix_full) %*% K_matrix_full %*% solve(J_matrix_full) / n
sigma_full_cluster = sqrt(diag(sigma_full_cluster))

### Calcul des écart-types clusterisés -- niveau departement
K_matrix_full_dep = K_matrix_cluster(eps=sweep(FS_residuals,MARGIN=1,reg_full$residuals,`*`), cluster_var=ID_dep, df_adj=0) # cluster au niveau du ménage
sigma_full_cluster_dep = solve(J_matrix_full) %*% K_matrix_full_dep %*% solve(J_matrix_full) / n
sigma_full_cluster_dep = sqrt(diag(sigma_full_cluster_dep))

### NB: cela ne change pas grand chose par rapport au niveau ménage -- réduction des écart-types de l'ordre de 5%.

############################################
############################################
### ETAPE 1: Selection par rapport à "Y" ###
############################################
############################################

# Il s'agit d'une régression Lasso classique
gamma_pen = .1/log(max(p,n))
lambda    = 1.1*qnorm(1-.5*gamma_pen/p)/sqrt(n) # niveau (theorique) de penalisation Lasso

outcome_selec = glmnet(X_2,Y,family="gaussian",alpha=1,lambda=lambda)
predict(outcome_selec,type="coef")

set_Y = unlist(predict(outcome_selec,type="nonzero")) # ensemble des coefficients non nuls à cette étape

naive_reg = lm(Y ~ X_1 + X_2[,set_Y]) # Naive regression
tau_naive = naive_reg$coefficients[coef_names]


##################################################################
##################################################################
### ETAPE 2: Selection par rapport à "X_1" avec le group Lasso ###
##################################################################
##################################################################

# Cette seconde étape est plus compliquée: la variable X_1 possèdre plusieurs modalités,
# Il faut donc binariser (les convertir en one-hot) et faire autant de régressions qu'il y a de modalités
# On propose une approche Group-Lasso dans la mesure où l'on suppose que le schéma de sparsité est le même pour toutes ces régressions.
# Cela nécessite de faire des régression empilées et de vectoriser la variable dépendante si on utilise le package grplasso, ce qui est très long.
# Depuis group-lasso implémenté manuellement.
# Pour le Group Lasso il y a donc p groupes de variables

# ajustement de la pénalisation
gamma_pen = .1/log(ncol(X_1)*max(p,n))
lambda    = 1.1*qnorm(1-.5*gamma_pen/(ncol(X_1)*p))/sqrt(n) # niveau (theorique) de penalisation Lasso

### VERSION A: avec le package grplasso -- ATTENTION TRES GOURMAND!
# X_1_vec = matrix(c(X_1), ncol=1)
# X_2_vec =  kronecker(diag(ncol(X_1)), X_2) # ATTENTION: Prend 8.5 Go de mémoire minimum...
# group_index = rep(1:p,ncol(X_1))
# 
# immunization_selec = grplasso(X_2_vec, X_1_vec, group_index, lambda=n*lambda, model=LinReg()) # ici la fonction objectif est differente, il faut multiplier la penalité par n
# Gamma_hat = matrix(immunization_selec$coefficients, ncol=ncol(X_1))
# row.names(Gamma_hat) = colnames(X_2)

### VERSION B: avec implémentation manuelle -- bien plus rapide, moins consommateur en mémoire
immunization_selec_man = group_lasso(X_2,X_1,lambda=lambda,trace=TRUE)
Gamma_hat = immunization_selec_man$beta[-p-1,]

set_X1 = c(which(apply(Gamma_hat>0,1,sum)>0))


###############################################
###############################################
### ETAPE 3: Estimateur de double sélection ###
###############################################
###############################################

S_hat = sort(union(set_Y,set_X1))
dbs_reg = lm(Y ~ X_1 + X_2[,S_hat])
tau_hat = dbs_reg$coefficients[coef_names]

### Calcul de l'écart-type clusterisé
S_hat = c(S_hat,ncol(X_2_tilde)) # ajouter la constante pour le calcul du Post-Lasso
Gamma_hat = solve(t(X_2_tilde[,S_hat])%*%X_2_tilde[,S_hat]) %*% (t(X_2_tilde[,S_hat]) %*% X_1) # Regression post-lasso de chaque modalités de X_1, on utilise un Ridge pour régulariser
treat_residuals = X_1 - X_2_tilde[,S_hat] %*% Gamma_hat

K_matrix = K_matrix_cluster(eps=sweep(treat_residuals,MARGIN=1,dbs_reg$residuals,`*`), cluster_var=ID_menage, df_adj=ncol(X_1) + length(S_hat) + 1) # cluster au niveau du ménage
J_matrix = t(treat_residuals)%*%treat_residuals / n
sigma = sqrt(solve(J_matrix) %*% K_matrix %*% solve(J_matrix)) / sqrt(n) 


#################
#################
### GRAPHIQUE ###
#################
#################

dip = data.frame("ID" = c("10","12","22","21","30","31","32","33","41","42","43","44","50","60","70"),
            "Diplome" = c("Master (recherche ou professionnel), DEA, DESS, Doctorat",
              "Ecoles niveau licence et au-delà",
              "Maîtrise (M1)",
              "Licence (L3)",
              "DEUG",
              "DUT, BTS",
              "Autre diplôme (niveau bac+2)",
              "Paramédical et social (niveau bac+2)",
              "Baccalauréat général",
              "Bac technologique",
              "Bac professionnel",
              "Brevet de technicien, brevet professionnel",
              "CAP, BEP",
              "Brevet des collèges",
              "Certificat d'études primaires"),
            "lower_bound" = tau_hat + qnorm(0.025)*diag(sigma),
            "Coefficient" = tau_hat,
            "upper_bound" = tau_hat + qnorm(0.975)*diag(sigma),
            "Moyenne" = tau_simple,
            "Naive" = tau_naive,
            "Full" = tau_full,
            "Full_lb" = tau_full + qnorm(0.025)*sigma_full_cluster,
            "Full_ub" = tau_full + qnorm(0.975)*sigma_full_cluster)

dodge = position_dodge(.7)

pdf(file="grandedim/plot/diplome_level.pdf", width=10, height=12)
ggplot(data=dip, aes(x = Diplome, y = Full, group=ID)) +
  geom_point(color="blue",fill="blue",shape=16) +
  geom_errorbar(aes(ymin  = Full_lb, ymax  = Full_ub, width = 0.2), color="blue") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size=16)) +
  scale_x_discrete(limits=rev(dip$Diplome)) +
  geom_point(aes(x = Diplome, y = Coefficient, group=ID), color="red",fill="red",shape=16, position = dodge) +
  geom_errorbar(aes(ymin  = lower_bound, ymax  = upper_bound, group=ID, width = 0.2), color = "red", position = dodge) +
  geom_abline(slope=0,intercept=0) +
  labs(x = "Niveau de diplôme", y = "Impact mesuré")
dev.off()

# Avec l'estimateur de double sélection, on repère facilement quatre groupes:
# 1) Sans diplôme / jusqu'au brevet des collèges,
# 2) Bac,
# 3) De Bac +2 à maitrise,
# 4) Master 2, écoles et au delà.


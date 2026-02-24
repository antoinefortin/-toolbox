#!/bin/bash

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA}$1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
}

# Vérifier les privilèges root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
}

# Vérifier Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé !"
        exit 1
    fi
    print_success "Docker est installé"
}

# Fonction pour demander un chemin avec valeur par défaut
ask_path() {
    local prompt=$1
    local default=$2
    local result

    read -p "$(echo -e ${CYAN}${prompt}${NC} [${default}]: )" result
    echo "${result:-$default}"
}

# Fonction pour demander confirmation
ask_confirm() {
    local prompt=$1
    local response

    read -p "$(echo -e ${YELLOW}${prompt}${NC} [o/N]: )" response
    [[ "$response" =~ ^[Oo]$ ]]
}

# Configuration
configure() {
    print_header "CONFIGURATION PORTAINER"

    BASE_DIR=$(ask_path "Répertoire de base pour les données" "/home/debian/data")
    PORTAINER_DATA=$(ask_path "Répertoire de données Portainer" "${BASE_DIR}/portainer/data")

    print_info "\n--- Configuration Caddy ---"
    if ask_confirm "Activer l'accès via Caddy (HTTPS avec sous-domaine) ?"; then
        USE_CADDY="true"
        DOMAIN=$(ask_path "Nom de domaine principal" "wyns.ovh")
        PORTAINER_SUBDOMAIN=$(ask_path "Sous-domaine pour Portainer" "portainer")
        PORTAINER_DOMAIN="${PORTAINER_SUBDOMAIN}.${DOMAIN}"

        CADDY_CONFIG=$(ask_path "Répertoire de configuration Caddy" "${BASE_DIR}/caddy/config")

        # Vérifier si Caddy existe
        if ! docker ps | grep -q caddy; then
            print_warning "Caddy ne semble pas être en cours d'exécution"
            print_warning "Assurez-vous que Caddy est installé ou désactivez cette option"
        fi
    else
        USE_CADDY="false"
        PORTAINER_PORT=$(ask_path "Port Web Portainer" "9000")
    fi

    # Résumé
    print_header "RÉSUMÉ"
    echo -e "${CYAN}Données Portainer:${NC} ${PORTAINER_DATA}"
    if [ "$USE_CADDY" = "true" ]; then
        echo -e "${CYAN}Accès:${NC} https://${PORTAINER_DOMAIN}"
        echo -e "${CYAN}Caddy Config:${NC} ${CADDY_CONFIG}"
    else
        echo -e "${CYAN}Port:${NC} ${PORTAINER_PORT}"
    fi
    echo ""

    if ! ask_confirm "Confirmer cette configuration ?"; then
        print_error "Configuration annulée"
        exit 1
    fi
}

# Créer les répertoires
create_directories() {
    print_header "CRÉATION DES RÉPERTOIRES"

    if [ ! -d "$PORTAINER_DATA" ]; then
        mkdir -p "$PORTAINER_DATA"
        print_success "Créé: $PORTAINER_DATA"
    else
        print_info "Existe déjà: $PORTAINER_DATA"
    fi
}

# Mettre à jour Caddyfile
update_caddyfile() {
    if [ "$USE_CADDY" != "true" ]; then
        return
    fi

    print_header "MISE À JOUR DU CADDYFILE"

    local caddyfile="${CADDY_CONFIG}/Caddyfile"

    if [ ! -f "$caddyfile" ]; then
        print_warning "Caddyfile n'existe pas, création..."
        mkdir -p "$CADDY_CONFIG"
        touch "$caddyfile"
    fi

    # Vérifier si Portainer existe déjà dans le Caddyfile
    if grep -q "$PORTAINER_DOMAIN" "$caddyfile"; then
        print_warning "Configuration Portainer existe déjà dans Caddyfile"
    else
        print_info "Ajout de la configuration Portainer au Caddyfile..."
        cat >> "$caddyfile" << EOFCADDY

# Portainer
${PORTAINER_DOMAIN} {
    reverse_proxy portainer:9000
    encode gzip
}
EOFCADDY
        print_success "Configuration ajoutée au Caddyfile"
    fi
}

# Installer Portainer
install_portainer() {
    print_header "INSTALLATION DE PORTAINER"

    # Vérifier si Portainer existe déjà
    if docker ps -a | grep -q portainer; then
        print_warning "Un conteneur Portainer existe déjà"
        if ask_confirm "Voulez-vous le supprimer et réinstaller ?"; then
            print_info "Suppression de l'ancien conteneur..."
            docker stop portainer 2>/dev/null
            docker rm portainer 2>/dev/null
        else
            print_error "Installation annulée"
            exit 1
        fi
    fi

    print_info "Téléchargement de l'image Portainer..."
    docker pull portainer/portainer-ce:latest

    print_info "Création du conteneur Portainer..."

    if [ "$USE_CADDY" = "true" ]; then
        # Mode avec Caddy - pas de port exposé
        docker run -d \
            --name portainer \
            --restart unless-stopped \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "${PORTAINER_DATA}:/data" \
            --network media-network \
            portainer/portainer-ce:latest
    else
        # Mode standalone avec port
        docker run -d \
            --name portainer \
            --restart unless-stopped \
            -p ${PORTAINER_PORT}:9000 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "${PORTAINER_DATA}:/data" \
            portainer/portainer-ce:latest
    fi

    print_success "Portainer installé avec succès"
}

# Redémarrer Caddy si nécessaire
restart_caddy() {
    if [ "$USE_CADDY" != "true" ]; then
        return
    fi

    print_header "REDÉMARRAGE DE CADDY"

    if docker ps | grep -q caddy; then
        print_info "Redémarrage de Caddy pour appliquer la nouvelle configuration..."
        docker restart caddy
        sleep 5
        print_success "Caddy redémarré"
    else
        print_warning "Caddy n'est pas en cours d'exécution"
        print_warning "Démarrez Caddy manuellement pour activer HTTPS"
    fi
}

# Afficher les informations
show_info() {
    print_header "INSTALLATION TERMINÉE ! 🚀"

    echo -e "${GREEN}✓ Portainer est maintenant installé !${NC}\n"

    if [ "$USE_CADDY" = "true" ]; then
        echo -e "${CYAN}Accès Portainer:${NC}"
        echo -e "  URL: ${GREEN}https://${PORTAINER_DOMAIN}${NC}"
        echo -e "  ${YELLOW}⚠ Assurez-vous que le DNS pointe vers ce serveur${NC}\n"
    else
        local ip=$(hostname -I | awk '{print $1}')
        echo -e "${CYAN}Accès Portainer:${NC}"
        echo -e "  URL: ${GREEN}http://${ip}:${PORTAINER_PORT}${NC}\n"
    fi

    echo -e "${CYAN}Première connexion:${NC}"
    echo -e "  1. Accédez à l'URL ci-dessus"
    echo -e "  2. Créez votre compte admin (première visite)"
    echo -e "  3. Sélectionnez 'Docker' comme environnement"
    echo -e "  4. C'est parti ! 🎉\n"

    echo -e "${CYAN}Fonctionnalités:${NC}"
    echo -e "  • Gérer tous vos conteneurs Docker"
    echo -e "  • Déployer des stacks Docker Compose"
    echo -e "  • App Templates (+ de 200 apps prêtes)"
    echo -e "  • Monitoring CPU/RAM en temps réel"
    echo -e "  • Logs et terminal web intégrés\n"

    echo -e "${CYAN}Commandes utiles:${NC}"
    echo -e "  docker logs -f portainer      # Voir les logs"
    echo -e "  docker restart portainer      # Redémarrer"
    echo -e "  docker stop portainer         # Arrêter"
    echo -e "  docker start portainer        # Démarrer\n"

    print_success "Bon déploiement tabarnak ! 🔥"
}

# Créer script de désinstallation
create_uninstall_script() {
    local uninstall_script="/tmp/uninstall_portainer.sh"

    cat > "$uninstall_script" << 'EOFUNINSTALL'
#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}⚠ ATTENTION: Ce script va supprimer Portainer !${NC}"
read -p "$(echo -e ${YELLOW}Êtes-vous sûr ? [o/N]: ${NC})" response

if [[ "$response" =~ ^[Oo]$ ]]; then
    echo "Arrêt et suppression de Portainer..."
    docker stop portainer
    docker rm portainer

    echo -e "${RED}Portainer supprimé${NC}"
    echo "Les données sont toujours dans: PORTAINER_DATA_PATH"
    echo "Supprimez-les manuellement si nécessaire"
else
    echo "Annulé"
fi
EOFUNINSTALL

    sed -i "s|PORTAINER_DATA_PATH|${PORTAINER_DATA}|g" "$uninstall_script"
    chmod +x "$uninstall_script"

    print_info "Script de désinstallation créé: ${uninstall_script}"
}

# Main
main() {
    print_header "🐳 INSTALLATION PORTAINER 🐳"
    echo -e "${MAGENTA}Let's go tabarnak ! 🔥${NC}\n"

    check_root
    check_docker
    configure
    create_directories
    update_caddyfile
    install_portainer
    restart_caddy
    create_uninstall_script
    show_info
}

main
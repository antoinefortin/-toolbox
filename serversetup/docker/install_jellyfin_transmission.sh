#!/bin/bash

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
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
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Vérifier les privilèges root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
}

# Installer Docker si nécessaire
install_docker() {
    if ! command -v docker &> /dev/null; then
        print_info "Docker n'est pas installé. Installation en cours..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        systemctl enable docker
        systemctl start docker
        print_success "Docker installé avec succès"
    else
        print_success "Docker est déjà installé"
    fi
}

# Installer Docker Compose si nécessaire
install_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_info "Docker Compose n'est pas installé. Installation en cours..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        print_success "Docker Compose installé avec succès"
    else
        print_success "Docker Compose est déjà installé"
    fi
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

# Configuration interactive
configure_paths() {
    print_header "CONFIGURATION DES CHEMINS"

    # Répertoire de base
    BASE_DIR=$(ask_path "Répertoire de base pour les données" "/home/debian/data")

    # Transmission
    print_info "\n--- Configuration Transmission ---"
    TRANSMISSION_CONFIG=$(ask_path "Répertoire de configuration Transmission" "${BASE_DIR}/transmission/config")
    TRANSMISSION_DOWNLOADS=$(ask_path "Répertoire de téléchargements Transmission" "${BASE_DIR}/transmission/downloads")
    TRANSMISSION_WATCH=$(ask_path "Répertoire watch pour les torrents" "${BASE_DIR}/transmission/watch")

    # Credentials Transmission
    TRANSMISSION_USER=$(ask_path "Utilisateur Transmission" "admin")
    read -sp "$(echo -e ${CYAN}Mot de passe Transmission:${NC} )" TRANSMISSION_PASS
    echo ""
    if [ -z "$TRANSMISSION_PASS" ]; then
        TRANSMISSION_PASS="changeme"
        print_warning "Mot de passe par défaut utilisé: changeme"
    fi

    # Jellyfin
    print_info "\n--- Configuration Jellyfin ---"
    JELLYFIN_CONFIG=$(ask_path "Répertoire de configuration Jellyfin" "${BASE_DIR}/jellyfin/config")
    JELLYFIN_CACHE=$(ask_path "Répertoire de cache Jellyfin" "${BASE_DIR}/jellyfin/cache")

    # Médias partagés
    print_info "\n--- Configuration Médias ---"
    MEDIA_MOVIES=$(ask_path "Répertoire pour les films" "${TRANSMISSION_DOWNLOADS}/movies")
    MEDIA_SERIES=$(ask_path "Répertoire pour les séries" "${TRANSMISSION_DOWNLOADS}/series")
    MEDIA_MUSIC=$(ask_path "Répertoire pour la musique" "${TRANSMISSION_DOWNLOADS}/music")

    # Ports
    print_info "\n--- Configuration Ports ---"
    TRANSMISSION_PORT=$(ask_path "Port Web Transmission" "9091")
    JELLYFIN_PORT=$(ask_path "Port Web Jellyfin" "8096")

    # PUID/PGID
    print_info "\n--- Configuration Utilisateur ---"
    PUID=$(ask_path "PUID (User ID)" "1000")
    PGID=$(ask_path "PGID (Group ID)" "1000")

    # Résumé
    print_header "RÉSUMÉ DE LA CONFIGURATION"
    echo -e "${CYAN}Base:${NC} ${BASE_DIR}"
    echo -e "${CYAN}Transmission Config:${NC} ${TRANSMISSION_CONFIG}"
    echo -e "${CYAN}Transmission Downloads:${NC} ${TRANSMISSION_DOWNLOADS}"
    echo -e "${CYAN}Transmission User:${NC} ${TRANSMISSION_USER}"
    echo -e "${CYAN}Jellyfin Config:${NC} ${JELLYFIN_CONFIG}"
    echo -e "${CYAN}Films:${NC} ${MEDIA_MOVIES}"
    echo -e "${CYAN}Séries:${NC} ${MEDIA_SERIES}"
    echo -e "${CYAN}Musique:${NC} ${MEDIA_MUSIC}"
    echo -e "${CYAN}Ports:${NC} Transmission=${TRANSMISSION_PORT}, Jellyfin=${JELLYFIN_PORT}"
    echo ""

    if ! ask_confirm "Confirmer cette configuration ?"; then
        print_error "Configuration annulée"
        exit 1
    fi
}

# Créer les répertoires nécessaires
create_directories() {
    print_header "CRÉATION DES RÉPERTOIRES"

    local dirs=(
        "$TRANSMISSION_CONFIG"
        "$TRANSMISSION_DOWNLOADS"
        "$TRANSMISSION_WATCH"
        "$JELLYFIN_CONFIG"
        "$JELLYFIN_CACHE"
        "$MEDIA_MOVIES"
        "$MEDIA_SERIES"
        "$MEDIA_MUSIC"
    )

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_success "Créé: $dir"
        else
            print_info "Existe déjà: $dir"
        fi
    done

    # Configurer les permissions
    print_info "Configuration des permissions..."
    chown -R ${PUID}:${PGID} "${BASE_DIR}"
    chmod -R 755 "${BASE_DIR}"
    print_success "Permissions configurées"
}

# Créer le docker-compose.yml
create_docker_compose() {
    print_header "CRÉATION DU DOCKER-COMPOSE"

    local compose_dir="${BASE_DIR}/compose"
    mkdir -p "$compose_dir"

    cat > "${compose_dir}/docker-compose.yml" << EOFCOMPOSE
version: '3.8'

services:
  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=Europe/Paris
      - USER=${TRANSMISSION_USER}
      - PASS=${TRANSMISSION_PASS}
    volumes:
      - ${TRANSMISSION_CONFIG}:/config
      - ${TRANSMISSION_DOWNLOADS}:/downloads
      - ${TRANSMISSION_WATCH}:/watch
    ports:
      - ${TRANSMISSION_PORT}:9091
      - 51413:51413
      - 51413:51413/udp
    restart: unless-stopped
    networks:
      - media-network

  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=Europe/Paris
    volumes:
      - ${JELLYFIN_CONFIG}:/config
      - ${JELLYFIN_CACHE}:/cache
      - ${MEDIA_MOVIES}:/data/movies
      - ${MEDIA_SERIES}:/data/tvshows
      - ${MEDIA_MUSIC}:/data/music
      - ${TRANSMISSION_DOWNLOADS}:/data/downloads:ro
    ports:
      - ${JELLYFIN_PORT}:8096
    restart: unless-stopped
    networks:
      - media-network

networks:
  media-network:
    driver: bridge
EOFCOMPOSE

    print_success "docker-compose.yml créé dans ${compose_dir}"

    # Créer un fichier .env
    cat > "${compose_dir}/.env" << EOFENV
PUID=${PUID}
PGID=${PGID}
TRANSMISSION_USER=${TRANSMISSION_USER}
TRANSMISSION_PASS=${TRANSMISSION_PASS}
TRANSMISSION_PORT=${TRANSMISSION_PORT}
JELLYFIN_PORT=${JELLYFIN_PORT}
BASE_DIR=${BASE_DIR}
TRANSMISSION_CONFIG=${TRANSMISSION_CONFIG}
TRANSMISSION_DOWNLOADS=${TRANSMISSION_DOWNLOADS}
TRANSMISSION_WATCH=${TRANSMISSION_WATCH}
JELLYFIN_CONFIG=${JELLYFIN_CONFIG}
JELLYFIN_CACHE=${JELLYFIN_CACHE}
MEDIA_MOVIES=${MEDIA_MOVIES}
MEDIA_SERIES=${MEDIA_SERIES}
MEDIA_MUSIC=${MEDIA_MUSIC}
EOFENV

    print_success ".env créé dans ${compose_dir}"

    # Sauvegarder le chemin du compose
    COMPOSE_DIR="$compose_dir"
}

# Démarrer les services
start_services() {
    print_header "DÉMARRAGE DES SERVICES"

    cd "$COMPOSE_DIR"

    print_info "Téléchargement des images Docker..."
    docker-compose pull

    print_info "Démarrage des conteneurs..."
    docker-compose up -d

    print_success "Services démarrés avec succès"
}

# Afficher les informations de connexion
show_info() {
    print_header "INFORMATIONS DE CONNEXION"

    local ip=$(hostname -I | awk '{print $1}')

    echo -e "${GREEN}✓ Installation terminée avec succès !${NC}\n"

    echo -e "${CYAN}Transmission:${NC}"
    echo -e "  URL: http://${ip}:${TRANSMISSION_PORT}"
    echo -e "  Utilisateur: ${TRANSMISSION_USER}"
    echo -e "  Mot de passe: ${TRANSMISSION_PASS}"
    echo -e "  ${YELLOW}Pour changer le mot de passe:${NC}"
    echo -e "    1. Modifier USER/PASS dans ${COMPOSE_DIR}/.env"
    echo -e "    2. Redémarrer: cd ${COMPOSE_DIR} && docker-compose restart transmission\n"

    echo -e "${CYAN}Jellyfin:${NC}"
    echo -e "  URL: http://${ip}:${JELLYFIN_PORT}"
    echo -e "  Configuration initiale requise lors de la première connexion\n"

    echo -e "${CYAN}Gestion:${NC}"
    echo -e "  Dossier compose: ${COMPOSE_DIR}"
    echo -e "  Commandes utiles:"
    echo -e "    cd ${COMPOSE_DIR}"
    echo -e "    docker-compose logs -f transmission  # Logs Transmission"
    echo -e "    docker-compose logs -f jellyfin      # Logs Jellyfin"
    echo -e "    docker-compose restart               # Redémarrer"
    echo -e "    docker-compose stop                  # Arrêter"
    echo -e "    docker-compose down                  # Arrêter et supprimer"
}

# Créer un script de nettoyage
create_cleanup_script() {
    local cleanup_script="${COMPOSE_DIR}/cleanup.sh"

    cat > "$cleanup_script" << 'EOFCLEANUP'
#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}⚠ ATTENTION: Ce script va supprimer tous les conteneurs et données !${NC}"
read -p "$(echo -e ${YELLOW}Êtes-vous sûr ? [o/N]: ${NC})" response

if [[ "$response" =~ ^[Oo]$ ]]; then
    echo "Arrêt des conteneurs..."
    docker-compose down -v

    echo "Suppression des données..."
    cd ..
    rm -rf transmission jellyfin compose

    echo -e "${RED}Nettoyage terminé${NC}"
else
    echo "Annulé"
fi
EOFCLEANUP

    chmod +x "$cleanup_script"
    print_success "Script de nettoyage créé: ${cleanup_script}"
}

# Main
main() {
    print_header "INSTALLATION TRANSMISSION + JELLYFIN"

    check_root
    configure_paths
    install_docker
    install_docker_compose
    create_directories
    create_docker_compose
    start_services
    create_cleanup_script
    show_info
}

main
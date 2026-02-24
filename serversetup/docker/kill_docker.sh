#!/bin/bash

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Vérifier si Docker est installé
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé"
        exit 1
    fi
}

# Afficher les ressources actuelles
show_current_state() {
    print_header "ÉTAT ACTUEL"

    local containers=$(docker ps -a -q | wc -l)
    local running=$(docker ps -q | wc -l)
    local images=$(docker images -q | wc -l)
    local volumes=$(docker volume ls -q | wc -l)
    local networks=$(docker network ls -q | wc -l)

    echo -e "${CYAN}Conteneurs:${NC} ${containers} (${running} en cours d'exécution)"
    echo -e "${CYAN}Images:${NC} ${images}"
    echo -e "${CYAN}Volumes:${NC} ${volumes}"
    echo -e "${CYAN}Networks:${NC} ${networks}"
    echo ""
}

# Menu interactif
show_menu() {
    print_header "NETTOYAGE DOCKER"
    echo "Choisissez une option:"
    echo ""
    echo "  1) Arrêter tous les conteneurs"
    echo "  2) Supprimer tous les conteneurs (arrêtés)"
    echo "  3) Supprimer toutes les images"
    echo "  4) Supprimer tous les volumes"
    echo "  5) Supprimer tous les networks (sauf défaut)"
    echo ""
    echo "  ${RED}6) NUCLEAR: Tout supprimer (conteneurs + images + volumes + networks)${NC}"
    echo "  ${RED}7) RESET COMPLET: Comme nuclear + purge du système${NC}"
    echo ""
    echo "  0) Quitter"
    echo ""
}

# Arrêter tous les conteneurs
stop_all_containers() {
    print_header "ARRÊT DES CONTENEURS"

    local containers=$(docker ps -q)
    if [ -z "$containers" ]; then
        print_info "Aucun conteneur en cours d'exécution"
        return
    fi

    print_info "Arrêt de tous les conteneurs..."
    docker stop $(docker ps -q)
    print_success "Tous les conteneurs sont arrêtés"
}

# Supprimer tous les conteneurs
remove_all_containers() {
    print_header "SUPPRESSION DES CONTENEURS"

    local containers=$(docker ps -a -q)
    if [ -z "$containers" ]; then
        print_info "Aucun conteneur à supprimer"
        return
    fi

    print_warning "Cette action va supprimer ${RED}TOUS${NC} les conteneurs"
    read -p "Confirmer ? [o/N]: " response

    if [[ "$response" =~ ^[Oo]$ ]]; then
        print_info "Arrêt des conteneurs en cours..."
        docker stop $(docker ps -q) 2>/dev/null
        print_info "Suppression des conteneurs..."
        docker rm -f $(docker ps -a -q)
        print_success "Tous les conteneurs ont été supprimés"
    else
        print_info "Annulé"
    fi
}

# Supprimer toutes les images
remove_all_images() {
    print_header "SUPPRESSION DES IMAGES"

    local images=$(docker images -q)
    if [ -z "$images" ]; then
        print_info "Aucune image à supprimer"
        return
    fi

    print_warning "Cette action va supprimer ${RED}TOUTES${NC} les images Docker"
    read -p "Confirmer ? [o/N]: " response

    if [[ "$response" =~ ^[Oo]$ ]]; then
        print_info "Suppression des images..."
        docker rmi -f $(docker images -q)
        print_success "Toutes les images ont été supprimées"
    else
        print_info "Annulé"
    fi
}

# Supprimer tous les volumes
remove_all_volumes() {
    print_header "SUPPRESSION DES VOLUMES"

    local volumes=$(docker volume ls -q)
    if [ -z "$volumes" ]; then
        print_info "Aucun volume à supprimer"
        return
    fi

    print_warning "Cette action va supprimer ${RED}TOUS${NC} les volumes (données persistantes)"
    read -p "Confirmer ? [o/N]: " response

    if [[ "$response" =~ ^[Oo]$ ]]; then
        print_info "Suppression des volumes..."
        docker volume rm $(docker volume ls -q) 2>/dev/null || docker volume prune -f
        print_success "Tous les volumes ont été supprimés"
    else
        print_info "Annulé"
    fi
}

# Supprimer tous les networks
remove_all_networks() {
    print_header "SUPPRESSION DES NETWORKS"

    print_warning "Cette action va supprimer tous les networks personnalisés"
    read -p "Confirmer ? [o/N]: " response

    if [[ "$response" =~ ^[Oo]$ ]]; then
        print_info "Suppression des networks..."
        docker network prune -f
        print_success "Networks nettoyés"
    else
        print_info "Annulé"
    fi
}

# Option NUCLEAR
nuclear_option() {
    print_header "⚠️  OPTION NUCLEAR  ⚠️"

    echo -e "${RED}ATTENTION: Cette action va TOUT supprimer:${NC}"
    echo "  - Tous les conteneurs (en cours et arrêtés)"
    echo "  - Toutes les images"
    echo "  - Tous les volumes (DONNÉES PERDUES)"
    echo "  - Tous les networks personnalisés"
    echo ""
    echo -e "${YELLOW}Cette action est IRRÉVERSIBLE${NC}"
    echo ""
    read -p "Tapez 'SUPPRIMER TOUT' pour confirmer: " response

    if [ "$response" = "SUPPRIMER TOUT" ]; then
        print_info "Début du nettoyage nuclear..."

        # Arrêter tout
        print_info "1/5 - Arrêt de tous les conteneurs..."
        docker stop $(docker ps -q) 2>/dev/null

        # Supprimer conteneurs
        print_info "2/5 - Suppression des conteneurs..."
        docker rm -f $(docker ps -a -q) 2>/dev/null

        # Supprimer images
        print_info "3/5 - Suppression des images..."
        docker rmi -f $(docker images -q) 2>/dev/null

        # Supprimer volumes
        print_info "4/5 - Suppression des volumes..."
        docker volume rm $(docker volume ls -q) 2>/dev/null

        # Supprimer networks
        print_info "5/5 - Suppression des networks..."
        docker network prune -f 2>/dev/null

        print_success "Nettoyage nuclear terminé"
        echo ""
        show_current_state
    else
        print_error "Confirmation incorrecte - Annulé"
    fi
}

# Reset complet du système
full_reset() {
    print_header "⚠️  RESET COMPLET  ⚠️"

    echo -e "${RED}ATTENTION: Cette action va:${NC}"
    echo "  - Exécuter l'option nuclear (tout supprimer)"
    echo "  - Nettoyer le cache et données système Docker"
    echo "  - Purger les ressources inutilisées"
    echo ""
    echo -e "${YELLOW}Cette action est IRRÉVERSIBLE${NC}"
    echo ""
    read -p "Tapez 'RESET COMPLET' pour confirmer: " response

    if [ "$response" = "RESET COMPLET" ]; then
        print_info "Début du reset complet..."

        # Nuclear d'abord
        docker stop $(docker ps -q) 2>/dev/null
        docker rm -f $(docker ps -a -q) 2>/dev/null
        docker rmi -f $(docker images -q) 2>/dev/null
        docker volume rm $(docker volume ls -q) 2>/dev/null
        docker network prune -f 2>/dev/null

        # Nettoyage système
        print_info "Nettoyage du système Docker..."
        docker system prune -a --volumes -f

        print_success "Reset complet terminé"
        echo ""
        show_current_state
    else
        print_error "Confirmation incorrecte - Annulé"
    fi
}

# Main
main() {
    check_docker

    while true; do
        echo ""
        show_current_state
        show_menu

        read -p "Votre choix: " choice

        case $choice in
            1) stop_all_containers ;;
            2) remove_all_containers ;;
            3) remove_all_images ;;
            4) remove_all_volumes ;;
            5) remove_all_networks ;;
            6) nuclear_option ;;
            7) full_reset ;;
            0)
                print_info "Au revoir!"
                exit 0
                ;;
            *)
                print_error "Option invalide"
                ;;
        esac

        echo ""
        read -p "Appuyez sur Entrée pour continuer..."
    done
}

# Vérifier si root
if [[ $EUID -ne 0 ]]; then
    print_warning "Ce script devrait être exécuté en tant que root (sudo)"
    read -p "Continuer quand même ? [o/N]: " response
    if [[ ! "$response" =~ ^[Oo]$ ]]; then
        exit 1
    fi
fi

main
#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

AUTO_MODE=false

if [[ "$1" == "-auto" ]]; then
    AUTO_MODE=true
    shift
fi


print_header() {
    echo
    echo
    echo -e "${WHITE}       shef auto completion setup      ${NC}\n"
    echo
}


print_success() { echo -e "[${GREEN}OKAY${NC}] $1"; }
print_error() { echo -e "[${RED}ERR${NC}] $1"; }
print_warning() { echo -e "[${YELLOW}WARN${NC}] $1"; }
print_info() { echo -e "[${CYAN}INFO${NC}] $1"; }
print_step() { echo -e "[${PURPLE}FATA${NC}] $1"; }
print_ask() { echo -e "[${PURPLE}Huh?${NC}]"; }


ask_permission() {
    if [ "$AUTO_MODE" = true ]; then
        return 0
    fi
    
    echo -e "${YELLOW}?${NC} $1 [y/n]: "
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

detect_system() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    GOVERSION=$(go version | cut -d ' ' -f3 | cut -c3-)

    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
    esac
    
    print_info "OS: ${WHITE}$OS${NC} | ARCH: ${WHITE}$ARCH${NC} | GO: ${WHITE}$GOVERSION${NC}"
}

verify_shef_binary() {
    local binary_path="$1"
    
    if [ ! -f "$binary_path" ]; then
        return 1
    fi
    
    if [ ! -x "$binary_path" ]; then
        return 1
    fi
    
    if ! "$binary_path" -list >/dev/null 2>&1; then
        return 1
    fi
    
    local facet_count=$("$binary_path" -list 2>/dev/null | wc -l)
    if [ "$facet_count" -lt 10 ]; then
        return 1
    fi
    
    return 0
}

find_shef_system() {
    print_step "searching for shef binary in system..."
    
    local search_paths=(
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "$HOME/bin"
        "$HOME/.local/bin"
        "$HOME/go/bin"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -f "$path/shef" ]; then
            print_info "found shef at: ${WHITE}$path/shef${NC}"
            if verify_shef_binary "$path/shef"; then
                print_success "verified shef binary at: ${WHITE}$path/shef${NC}"
                return 0
            else
                print_warning "binary at $path/shef failed verification"
            fi
        fi
    done
    
    print_step "performing deep search in filesystem..."
    print_warning "this may take a while..."
    
    local found_binaries=()
    while IFS= read -r -d '' binary; do
        found_binaries+=("$binary")
    done < <(find /usr /opt /home 2>/dev/null -name "shef" -type f -executable -print0 2>/dev/null | head -20)
    
    if [ ${#found_binaries[@]} -eq 0 ]; then
        print_error "no shef binary found in system"
        return 1
    fi
    
    for binary in "${found_binaries[@]}"; do
        print_info "checking: ${WHITE}$binary${NC}"
        if verify_shef_binary "$binary"; then
            print_success "verified shef binary at: ${WHITE}$binary${NC}"
            if ask_permission "add $binary to PATH?"; then
                export PATH="$(dirname "$binary"):$PATH"
                print_success "added to current session path"
            fi
            return 0
        fi
    done
    
    print_error "no valid shef binary found"
    return 1
}

check_go_installation() {
    if ! command -v go >/dev/null 2>&1; then
        print_error "go is not installed"
        print_info "please install go from: ${WHITE}https://golang.org/dl/${NC}"
        return 1
    fi
    
    local go_version=$(go version | cut -d' ' -f3)
    print_success "found go: ${WHITE}$go_version${NC}"
    
    local gopath=$(go env GOPATH)
    local gobin=$(go env GOBIN)
    local goroot=$(go env GOROOT)
    
    print_info "gopath: ${WHITE}${gopath:-not set}${NC}"
    print_info "gobin: ${WHITE}${gobin:-not set}${NC}"
    print_info "goroot: ${WHITE}$goroot${NC}"
    
    if [ -z "$gobin" ]; then
        gobin="$gopath/bin"
    fi
    
    print_info "shef will be installed to: ${WHITE}$gobin/shef${NC}"
    
    if [[ ":$PATH:" != *":$gobin:"* ]]; then
        print_warning "go bin directory not in path"
        if ask_permission "add $gobin to path?"; then
            export PATH="$gobin:$PATH"
            print_success "added to current session path"
            
            local shell_rc
            case $(basename "$SHELL") in
                bash) shell_rc="$HOME/.bashrc" ;;
                zsh) shell_rc="$HOME/.zshrc" ;;
                fish) shell_rc="$HOME/.config/fish/config.fish" ;;
                *) shell_rc="$HOME/.profile" ;;
            esac
            
            if ask_permission "add $gobin to $shell_rc permanently?"; then
                echo "export PATH=\"$gobin:\$PATH\"" >> "$shell_rc"
                print_success "added to $shell_rc"
            fi
        fi
    fi
    
    return 0
}

install_shef() {
    print_step "installing shef from github.com/1hehaq/shef..."
    
    if ! check_go_installation; then
        return 1
    fi
    
    if ! ask_permission "install shef using 'go install github.com/1hehaq/shef@latest'?"; then
        print_error "installation cancelled"
        return 1
    fi
    
    print_step "running go install..."
    
    if go install github.com/1hehaq/shef@latest; then
        print_success "shef installed successfully"
        
        local gobin=$(go env GOBIN)
        if [ -z "$gobin" ]; then
            gobin="$(go env GOPATH)/bin"
        fi
        
        local shef_path="$gobin/shef"
        if [ -f "$shef_path" ]; then
            print_success "shef binary located at: ${WHITE}$shef_path${NC}"
            
            if verify_shef_binary "$shef_path"; then
                print_success "shef installation verified"
                return 0
            else
                print_error "shef installation failed verification"
                return 1
            fi
        else
            print_error "shef binary not found after installation"
            return 1
        fi
    else
        print_error "failed to install shef"
        return 1
    fi
}

check_shef() {
    if command -v shef >/dev/null 2>&1; then
        SHEF_PATH=$(which shef)
        print_success "found shef at: ${WHITE}$SHEF_PATH${NC}"
        
        if verify_shef_binary "$SHEF_PATH"; then
            FACET_COUNT=$(shef -list 2>/dev/null | wc -l)
            print_info "available facets: ${WHITE}$FACET_COUNT${NC}"
            return 0
        else
            print_warning "shef found but verification failed"
        fi
    fi
    
    print_warning "shef not found in path"
    
    if find_shef_system; then
        return 0
    fi
    
    print_step "attempting to install shef..."
    
    if install_shef; then
        return 0
    else
        print_error "failed to install shef"
        return 1
    fi
}

detect_shells() {
    SHELLS=()
    
    if command -v bash >/dev/null 2>&1; then
        SHELLS+=("bash")
    fi
    
    if command -v zsh >/dev/null 2>&1; then
        SHELLS+=("zsh")
    fi
    
    if command -v fish >/dev/null 2>&1; then
        SHELLS+=("fish")
    fi
    
    if [ ${#SHELLS[@]} -eq 0 ]; then
        print_error "no supported shells found (bash, zsh, fish)"
        exit 1
    fi
    
    print_success "detected shell: ${WHITE}${SHELLS[*]}${NC}"
}

current_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    elif [ -n "$FISH_VERSION" ]; then
        echo "fish"
    else
        basename "$SHELL"
    fi
}

setup_bash() {
    # print_step "setting up bash completion..."
    
    COMP_DIR="$HOME/.bash_completion.d"
    mkdir -p "$COMP_DIR"
    
    cat > "$COMP_DIR/shef" << 'EOF'
_shef_completion() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    case "${prev}" in
        -f|--facet)
            COMPREPLY=($(compgen -W "$(shef -list 2>/dev/null)" -- ${cur}))
            ;;
        *)
            COMPREPLY=($(compgen -W "-q -f -json -list -h" -- ${cur}))
            ;;
    esac
}
complete -F _shef_completion shef
EOF

    BASHRC="$HOME/.bashrc"
    if ! grep -q "source.*shef" "$BASHRC" 2>/dev/null; then
        echo "source $COMP_DIR/shef" >> "$BASHRC"
        print_success "added to ~/.bashrc"
    else
        print_warning "already configured in ~/.bashrc"
    fi
}

setup_zsh() {
    print_step "setting up zsh completion..."
    
    COMP_DIR="$HOME/.zsh/completions"
    mkdir -p "$COMP_DIR"
    
    cat > "$COMP_DIR/_shef" << 'EOF'
#compdef shef
_shef() {
    case $words[CURRENT-1] in
        -f|--facet)
            _values 'facets' ${(f)"$(shef -list 2>/dev/null)"}
            ;;
        *)
            _arguments '-q[query]' '-f[facet]' '-json[json output]' '-list[list facets]' '-h[help]'
            ;;
    esac
}
EOF

    ZSHRC="$HOME/.zshrc"
    if ! grep -q "fpath.*completions" "$ZSHRC" 2>/dev/null; then
        echo "fpath=(~/.zsh/completions \$fpath)" >> "$ZSHRC"
        echo "autoload -U compinit && compinit" >> "$ZSHRC"
        print_success "added to ~/.zshrc"
    else
        print_warning "already configured in ~/.zshrc"
    fi
}

setup_fish() {
    print_step "setting up fish completion..."
    
    COMP_DIR="$HOME/.config/fish/completions"
    mkdir -p "$COMP_DIR"
    
    cat > "$COMP_DIR/shef.fish" << 'EOF'
complete -c shef -s f -l facet -f -a "(shef -list 2>/dev/null)"
complete -c shef -s q -l query -f -d "search query"
complete -c shef -l json -f -d "json output"
complete -c shef -l list -f -d "list facets"
complete -c shef -s h -l help -f -d "show help"
EOF

    print_success "fish completion installed"
}


ask_permission() {
    local prompt="$1"
    local answer
    read -rp "$(print_ask) ${prompt} [y/n]: " answer
    [[ "$answer" == [Yy] ]]
}

install_completions() {
    echo

    for shell in "${SHELLS[@]}"; do
        local msg="install $shell completion?"
        if ask_permission "$msg"; then
            case $shell in
                bash) setup_bash ;;
                zsh) setup_zsh ;;
                fish) setup_fish ;;
            esac
        else
            print_warning "skipped $shell completion"
        fi
    done
}


print_instructions() {
    echo
    echo
    print_step "${WHITE}activation instructions${NC}"
    echo
    
    CURRENT_SHELL=$(current_shell)
    
    for shell in "${SHELLS[@]}"; do
        case $shell in
            bash)
                if [ "$CURRENT_SHELL" = "bash" ]; then
                    echo -e "${GREEN}●${NC} ${WHITE}bash${NC} (current): ${YELLOW}source ~/.bashrc${NC}"
                else
                    echo -e "${WHITE}●${NC} ${WHITE}bash${NC}: ${YELLOW}source ~/.bashrc${NC}"
                fi
                ;;
            zsh)
                if [ "$CURRENT_SHELL" = "zsh" ]; then
                    echo -e "${GREEN}●${NC} ${WHITE}zsh${NC} (current): ${YELLOW}source ~/.zshrc${NC}"
                else
                    echo -e "${WHITE}●${NC} ${WHITE}zsh${NC}: ${YELLOW}source ~/.zshrc${NC}"
                fi
                ;;
            fish)
                if [ "$CURRENT_SHELL" = "fish" ]; then
                    echo -e "${GREEN}●${NC} ${WHITE}fish${NC} (current): ${YELLOW}exec fish${NC}"
                else
                    echo -e "${WHITE}●${NC} ${WHITE}fish${NC}: ${YELLOW}exec fish${NC}"
                fi
                ;;
        esac
    done
}

auto_reload() {
    CURRENT_SHELL=$(current_shell)
    
    case $CURRENT_SHELL in
        bash)
            if [[ "${SHELLS[*]}" =~ "bash" ]]; then
                if ask_permission "reload bash configuration now?"; then
                    # print_step "reloading bash configuration..."
                    source ~/.bashrc 2>/dev/null || true
                    print_success "bash completion activated"
                fi
            fi
            ;;
        zsh)
            if [[ "${SHELLS[*]}" =~ "zsh" ]]; then
                if ask_permission "reload zsh configuration now?"; then
                    # print_step "reloading zsh configuration..."
                    source ~/.zshrc 2>/dev/null || true
                    print_success "zsh completion activated"
                fi
            fi
            ;;
    esac
}

print_footer() {
    echo
    # echo -e "${WHITE}       setup complete      ${NC}"
    echo
    echo -e "${GREEN}try it out:${NC}"
    echo -e "   ${WHITE}shef -q \"apache\" -f <tab>${NC}"
    echo -e "   ${WHITE}shef -q \"nginx\" -f http.<tab>${NC}"
    echo
    
    # if [ "$AUTO_MODE" = true ]; then
    #     print_info "ran in auto mode - all permissions granted automatically"
    # fi
}

# show_usage() {
#     echo "usage: $0 [-auto]"
#     echo
#     echo "options:"
#     echo "  -auto    automatically grant all permissions"
#     echo
#     exit 1
# }

main() {
    # if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    #     show_usage
    # fi
    
    clear
    print_header
    
    if [ "$AUTO_MODE" = true ]; then
        print_info "running in auto mode (automatically grant permissions)"
        echo
    fi
    

    detect_system
    detect_shells
    check_shef
    # echo
    install_completions
    print_instructions
    # echo
    auto_reload
    print_footer
}

main "$@"

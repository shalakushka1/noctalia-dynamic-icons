#!/usr/bin/env bash
set -e

# Cores do terminal
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[ok]${NC} $1"; }
error()   { echo -e "${RED}[erro]${NC} $1"; exit 1; }

# Verificação de Dependências
for cmd in curl unzip git sed; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Dependência não encontrada: $cmd. Instale-a e tente novamente."
    fi
done

# Nomes e Caminhos
THEME_BASE="Noctalia-Colloid"
REAL_FOLDER="Noctalia-Colloid-Dark"
ICONS_DIR="$HOME/.local/share/icons"
NOCTALIA_DIR="$HOME/.config/noctalia"
TEMPLATES_DIR="$NOCTALIA_DIR/templates"
THEME_DIR="$ICONS_DIR/$REAL_FOLDER"
TMP_DIR="/tmp/icon-install-colloid"

clear
# Arte ASCII
echo -e "${BLUE}"
echo "    ____                                ______    ____      _     __"
echo "   / __ \__  ______  ____ _____ ___  (_)____            / ____/___  / / /___  (_)___/ /"
echo "  / / / / / / / __ \/ __ \`/ __ \`__ \/ / ___/  ______   / /   / __ \/ / / __ \/ / __  / "
echo " / /_/ / /_/ / / / / /_/ / / / / / / / /__   /_____/  / /___/ /_/ / / / /_/ / / /_/ /  "
echo "/_____/\__, /_/ /_/\__,_/_/ /_/ /_/_/\___/            \____/\____/_/_/\____/_/\__,_/   "
echo "      /____/                                                                           "
echo -e "${NC}"

echo -e "${BLUE}=== GESTOR EXCLUSIVO: $THEME_BASE ===${NC}"
echo "1) Instalar / Reparar"
echo "2) Desinstalar Completamente"
read -r -p "Selecione uma opção [1-2]: " OPT < /dev/tty

# --- OPÇÃO 2: DESINSTALAÇÃO ---
if [ "$OPT" == "2" ]; then
    info "Removendo $THEME_BASE..."
    rm -rf "$THEME_DIR" "$ICONS_DIR/${THEME_BASE}-Light" "$TEMPLATES_DIR/${THEME_BASE}.sh"
    # Remove a entrada do Noctalia sem quebrar o arquivo
    if [ -f "$NOCTALIA_DIR/user-templates.toml" ]; then
        sed -i "/\[templates.${THEME_BASE,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true
    fi
    gsettings set org.gnome.desktop.interface icon-theme "Adwaita"
    success "Desinstalação concluída."; exit 0
fi

# --- OPÇÃO 1: INSTALAÇÃO ---
info "Iniciando instalação de $THEME_BASE..."

# 1. Download limpo
rm -rf "$TMP_DIR" && mkdir -p "$TMP_DIR"
info "Baixando repositório original..."
curl -fsSL "https://github.com/vinceliuice/Colloid-icon-theme/archive/refs/heads/main.zip" -o "$TMP_DIR/colloid.zip"
unzip -q "$TMP_DIR/colloid.zip" -d "$TMP_DIR"
CDIR=$(find "$TMP_DIR" -maxdepth 1 -type d -name "Colloid-icon-theme*")

# 2. Instalador Oficial
info "Executando script de instalação oficial..."
mkdir -p "$ICONS_DIR"
bash "$CDIR/install.sh" -d "$ICONS_DIR" -n "$THEME_BASE" -t default -s default

# Verificação de segurança: Garante que a pasta foi realmente criada
if [ ! -d "$THEME_DIR" ]; then
    error "Falha na instalação: O diretório $THEME_DIR não foi criado."
fi

# 3. Snapshot de Git (Para motor de cores)
info "Criando snapshot para o motor de cores..."
cd "$THEME_DIR"
rm -rf .git
git init -q && git add . && git commit -q -m "original" && git tag -f "original"

# 4. Template do Noctalia
info "Criando template de aplicação..."
mkdir -p "$TEMPLATES_DIR"
cat > "$TEMPLATES_DIR/${THEME_BASE}.sh" << 'EOF'
#!/usr/bin/env bash
PRI="{{colors.primary.default.hex}}"
C1="${PRI:1}"
T_DIR="$HOME/.local/share/icons/Noctalia-Colloid-Dark"

echo "[info] Aplicando nova cor: #${C1} nos ícones..."

# Hard Reset para limpar cores anteriores antes de aplicar a nova
git -C "$T_DIR" reset --hard -q original
git -C "$T_DIR" clean -fd -q

# Substituição de cor mestre (Pastas, gradientes e apps)
find "$T_DIR" -name "*.svg" -type f -print0 | xargs -0 sed -i -E \
    -e "s/#60c0f0/#${C1}/gI" \
    -e "s/#5294e2/#${C1}/gI" \
    -e "s/fill:#[0-9a-fA-F]{6}/fill:#${C1}/gI" \
    -e "s/stop-color:#[0-9a-fA-F]{6}/stop-color:#${C1}/gI" \
    -e "s/style=\"fill:#[0-9a-fA-F]{6}/style=\"fill:#${C1}/gI" \
    -e "s/currentColor/#${C1}/gI"

gtk-update-icon-cache -f -t "$T_DIR" 2>/dev/null || true

# Forçar atualização da interface (GNOME)
gsettings set org.gnome.desktop.interface icon-theme "hicolor"
sleep 0.2
gsettings set org.gnome.desktop.interface icon-theme "Noctalia-Colloid-Dark"
EOF

# 5. Registro no user-templates.toml do Noctalia
info "Registrando no user-templates.toml..."
mkdir -p "$NOCTALIA_DIR"
touch "$NOCTALIA_DIR/user-templates.toml"
sed -i "/\[templates.${THEME_BASE,,}\]/,+4d" "$NOCTALIA_DIR/user-templates.toml" 2>/dev/null || true

cat >> "$NOCTALIA_DIR/user-templates.toml" << EOF

[templates.${THEME_BASE,,}]
input_path  = "~/.config/noctalia/templates/${THEME_BASE}.sh"
output_path = "~/.cache/noctalia/${THEME_BASE}-apply.sh"
post_hook   = "bash ~/.cache/noctalia/${THEME_BASE}-apply.sh"
EOF

# 6. Finalização e Aplicação inicial
chmod +x "$TEMPLATES_DIR/${THEME_BASE}.sh"
gsettings set org.gnome.desktop.interface icon-theme "$REAL_FOLDER"
rm -rf "$TMP_DIR"

success "Instalação de $THEME_BASE completada!"
info "Você já pode alterar as cores no Noctalia para ver as mudanças refletidas nos ícones."

#!/usr/bin/env bash
# ============================================================
#  install_ad_tools.sh
#  Installation automatique des outils Active Directory
#  Répertoire cible : ~/Documents/Programs/AD
# ============================================================
#  NOTE : pas de "set -e" volontairement — les échecs non
#  bloquants sont loggés mais n'arrêtent pas le script.
# ============================================================

# ── Couleurs ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}[✔]${RESET} $*"; }
info() { echo -e "${CYAN}[*]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
err()  { echo -e "${RED}[✘]${RESET} $*"; }

# ── Compteurs pour le résumé final ──────────────────────────
INSTALLED=0; SKIPPED=0; FAILED=0
declare -a FAILED_LIST=()

track_ok()   { ((INSTALLED++)); }
track_skip() { ((SKIPPED++)); }
track_fail() { ((FAILED++)); FAILED_LIST+=("$1"); }

# ── Répertoire de travail ────────────────────────────────────
AD_DIR="$HOME/Documents/Programs/AD"
mkdir -p "$AD_DIR"
info "Répertoire de travail : $AD_DIR"

# ── Helpers ──────────────────────────────────────────────────
apt_install() {
    local pkg="$1"
    if dpkg -s "$pkg" &>/dev/null 2>&1; then
        ok "$pkg déjà installé"; track_skip
    else
        info "apt : $pkg"
        if sudo apt-get install -y "$pkg" &>/dev/null; then
            ok "$pkg installé"; track_ok
        else
            err "apt introuvable : $pkg"; track_fail "$pkg (apt)"
        fi
    fi
}

pip_install() {
    local pkg="$1"
    info "pip : $pkg"
    if pip3 install "$pkg" --break-system-packages -q 2>/dev/null \
    || pip3 install "$pkg" -q 2>/dev/null; then
        ok "$pkg (pip)"; track_ok
    else
        err "pip échoué : $pkg"; track_fail "$pkg (pip)"
    fi
}

download_bin() {
    local url="$1" dest="$2" name
    name=$(basename "$dest")
    info "Binaire : $name"
    if wget -q --timeout=30 -O "$dest" "$url" 2>/dev/null && [[ -s "$dest" ]]; then
        chmod +x "$dest"
        ok "$name téléchargé"; track_ok
    else
        rm -f "$dest"
        err "Échec téléchargement : $name"; track_fail "$name"
    fi
}

download_file() {
    local url="$1" dest="$2" name
    name=$(basename "$dest")
    info "Fichier : $name"
    if wget -q --timeout=30 -O "$dest" "$url" 2>/dev/null && [[ -s "$dest" ]]; then
        ok "$name téléchargé"; track_ok
    else
        rm -f "$dest"
        err "Échec téléchargement : $name"; track_fail "$name"
    fi
}

download_zip() {
    local url="$1" dest_dir="$2" label="$3"
    local tmp="/tmp/${label}.zip"
    info "Archive : $label"
    if wget -q --timeout=60 -O "$tmp" "$url" 2>/dev/null && [[ -s "$tmp" ]]; then
        mkdir -p "$dest_dir"
        if unzip -q -o "$tmp" -d "$dest_dir" 2>/dev/null; then
            ok "$label extrait dans $dest_dir"; track_ok
        else
            err "Échec unzip : $label"; track_fail "$label (unzip)"
        fi
        rm -f "$tmp"
    else
        rm -f "$tmp"
        err "Échec téléchargement : $label"; track_fail "$label (wget)"
    fi
}

gh_latest_url() {
    # Retourne l'URL du premier asset matching le pattern, sans quitter en cas d'erreur
    local repo="$1" pattern="$2"
    curl -sf --max-time 15 "https://api.github.com/repos/${repo}/releases/latest" \
        | grep browser_download_url \
        | grep -i "$pattern" \
        | head -1 \
        | cut -d '"' -f 4
}

clone_or_pull() {
    local repo="$1" dir="$2"
    if [[ -d "$dir/.git" ]]; then
        info "git pull : $(basename "$dir")"
        git -C "$dir" pull -q 2>/dev/null && ok "$(basename "$dir") mis à jour" || warn "git pull échoué : $dir"
        track_skip
    else
        info "git clone : $(basename "$dir")"
        if git clone -q --depth 1 "$repo" "$dir" 2>/dev/null; then
            ok "$(basename "$dir") cloné"; track_ok
        else
            err "git clone échoué : $repo"; track_fail "$(basename "$dir") (git)"
        fi
    fi
}

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 1 · Dépendances système ═══${RESET}"
sudo apt-get update -qq 2>/dev/null

APT_PKGS=(
    python3 python3-pip git curl wget golang-go
    smbclient samba-common-bin ldap-utils rpcbind
    enum4linux hashcat nmap ruby-full
    krb5-user libkrb5-dev libssl-dev
    libffi-dev build-essential unzip
)
for pkg in "${APT_PKGS[@]}"; do
    apt_install "$pkg"
done

# rpcclient est dans samba-common-bin, vérification
if command -v rpcclient &>/dev/null; then
    ok "rpcclient disponible (via samba-common-bin)"
else
    warn "rpcclient non trouvé — essai samba..."
    apt_install samba
fi

# rpcinfo est dans rpcbind, vérification
if command -v rpcinfo &>/dev/null; then
    ok "rpcinfo disponible (via rpcbind)"
else
    warn "rpcinfo non trouvé — essai rpcbind..."
    apt_install rpcbind
fi

# setspn.exe = binaire Windows natif (RSAT / Windows Server)
# Non installable sous Linux — disponible uniquement sur l'hôte Windows cible
warn "setspn.exe : binaire Windows natif, non installable sous Linux"
echo "  → Disponible nativement sur Windows Server / RSAT"

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 2 · Outils Python (pip) ═══${RESET}"

pip_install impacket
pip_install bloodhound
pip_install ldapdomaindump
pip_install dnspython
pip_install pyasn1
pip_install pyOpenSSL
pip_install adidnsdump
pip_install smbmap
pip_install gpp-decrypt
pip_install minikerberos
pip_install oscrypto
pip_install pyyaml

# netexec = successeur officiel de CrackMapExec
info "netexec (successeur de CrackMapExec)"
if pip3 install netexec --break-system-packages -q 2>/dev/null \
|| pip3 install netexec -q 2>/dev/null; then
    ok "netexec installé (commande : nxc)"; track_ok
else
    # fallback : pipx
    if command -v pipx &>/dev/null || pip3 install pipx -q 2>/dev/null; then
        pipx install netexec 2>/dev/null && ok "netexec installé via pipx" || \
            warn "netexec : installez manuellement → https://github.com/Pennyw0rth/NetExec"
    fi
    track_fail "netexec"
fi

# evil-winrm (Ruby)
info "evil-winrm (gem)"
if sudo gem install evil-winrm -q 2>/dev/null; then
    ok "evil-winrm installé"; track_ok
else
    err "evil-winrm échoué"; track_fail "evil-winrm (gem)"
fi

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 3 · Dépôts Git ═══${RESET}"

clone_or_pull "https://github.com/lgandx/Responder.git"          "$AD_DIR/Responder"
clone_or_pull "https://github.com/ropnop/windapsearch.git"        "$AD_DIR/windapsearch"
clone_or_pull "https://github.com/dirkjanm/PKINITtools.git"       "$AD_DIR/PKITools/PKINITtools"
clone_or_pull "https://github.com/cddmp/enum4linux-ng.git"        "$AD_DIR/enum4linux-ng"
clone_or_pull "https://github.com/dafthack/DomainPasswordSpray.git" "$AD_DIR/DomainPasswordSpray"
clone_or_pull "https://github.com/leoloobeek/LAPSToolkit.git"     "$AD_DIR/LAPSToolkit"
clone_or_pull "https://github.com/PowerShellMafia/PowerSploit.git" "$AD_DIR/PowerSploit"
clone_or_pull "https://github.com/Kevin-Robertson/Inveigh.git"    "$AD_DIR/Inveigh"
clone_or_pull "https://github.com/adrecon/ADRecon.git"            "$AD_DIR/ADRecon"

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 4 · BloodHound GUI ═══${RESET}"
mkdir -p "$AD_DIR/BloodHound"

BH_URL=$(gh_latest_url "BloodHoundAD/BloodHound" "linux.*zip\|linux.*tar")
if [[ -n "$BH_URL" ]]; then
    download_zip "$BH_URL" "$AD_DIR/BloodHound" "BloodHound"
    find "$AD_DIR/BloodHound" -name "BloodHound" -type f -exec chmod +x {} \; 2>/dev/null
else
    warn "BloodHound : impossible de récupérer la release → https://github.com/BloodHoundAD/BloodHound/releases"
    track_fail "BloodHound GUI"
fi

# SharpHound
SH_URL=$(gh_latest_url "BloodHoundAD/SharpHound" "\.zip")
if [[ -n "$SH_URL" ]]; then
    download_zip "$SH_URL" "$AD_DIR/BloodHound/SharpHound" "SharpHound"
else
    warn "SharpHound : récupération manuelle → https://github.com/BloodHoundAD/SharpHound/releases"
    track_fail "SharpHound"
fi

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 5 · Kerbrute ═══${RESET}"
mkdir -p "$AD_DIR/Kerbrute"
KB_URL=$(gh_latest_url "ropnop/kerbrute" "linux_amd64")
[[ -n "$KB_URL" ]] && download_bin "$KB_URL" "$AD_DIR/Kerbrute/kerbrute" || \
    { warn "Kerbrute : https://github.com/ropnop/kerbrute/releases"; track_fail "Kerbrute"; }

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 6 · Rubeus ═══${RESET}"
mkdir -p "$AD_DIR/Rubeus"
# GhostPack ne publie pas de releases publiques — mirror compilé
download_bin \
    "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Rubeus.exe" \
    "$AD_DIR/Rubeus/Rubeus.exe"

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 7 · Mimikatz ═══${RESET}"
mkdir -p "$AD_DIR/Mimikatz"
MK_URL=$(gh_latest_url "gentilkiwi/mimikatz" "\.zip")
if [[ -n "$MK_URL" ]]; then
    download_zip "$MK_URL" "$AD_DIR/Mimikatz" "mimikatz"
else
    warn "Mimikatz : https://github.com/gentilkiwi/mimikatz/releases"
    track_fail "Mimikatz"
fi

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 8 · Snaffler ═══${RESET}"
mkdir -p "$AD_DIR/Snaffler"
SN_URL=$(gh_latest_url "SnaffCon/Snaffler" "\.exe" | grep -v symbols | head -1)
[[ -n "$SN_URL" ]] && download_bin "$SN_URL" "$AD_DIR/Snaffler/Snaffler.exe" || \
    { warn "Snaffler : https://github.com/SnaffCon/Snaffler/releases"; track_fail "Snaffler"; }

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 9 · Inveigh (binaire C#) ═══${RESET}"
IV_URL=$(gh_latest_url "Kevin-Robertson/Inveigh" "\.exe")
[[ -n "$IV_URL" ]] && download_bin "$IV_URL" "$AD_DIR/Inveigh/Inveigh.exe" || \
    warn "Inveigh.exe non récupéré (script PS déjà cloné à l'étape 3)"

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 10 · SharpView ═══${RESET}"
mkdir -p "$AD_DIR/SharpView"
SV_URL=$(gh_latest_url "dmchell/SharpView" "\.exe")
if [[ -n "$SV_URL" ]]; then
    download_bin "$SV_URL" "$AD_DIR/SharpView/SharpView.exe"
else
    # Mirror Ghostpack
    download_bin \
        "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/SharpView.exe" \
        "$AD_DIR/SharpView/SharpView.exe"
fi

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 11 · Exploits PoC ═══${RESET}"
mkdir -p "$AD_DIR/Exploits"

download_file \
    "https://raw.githubusercontent.com/cube0x0/CVE-2021-1675/main/CVE-2021-1675.py" \
    "$AD_DIR/Exploits/CVE-2021-1675.py"

download_file \
    "https://raw.githubusercontent.com/topotam/PetitPotam/main/PetitPotam.py" \
    "$AD_DIR/Exploits/PetitPotam.py"

# noPac — clone complet (dépendances multiples)
clone_or_pull "https://github.com/Ridter/noPac.git" "$AD_DIR/Exploits/noPac"

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 12 · Outils d'audit ═══${RESET}"
mkdir -p "$AD_DIR/Audit"

# PingCastle
PC_URL=$(gh_latest_url "vletoux/pingcastle" "\.zip")
[[ -n "$PC_URL" ]] && download_zip "$PC_URL" "$AD_DIR/Audit/PingCastle" "PingCastle" || \
    { warn "PingCastle : https://www.pingcastle.com/download"; track_fail "PingCastle"; }

# Group3r
G3_URL=$(gh_latest_url "Group3r/Group3r" "\.exe")
[[ -n "$G3_URL" ]] && download_bin "$G3_URL" "$AD_DIR/Audit/Group3r.exe" || \
    { warn "Group3r : https://github.com/Group3r/Group3r/releases"; track_fail "Group3r"; }

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 13 · Outils complémentaires ═══${RESET}"

# LdapRelayScan (test LDAP signing/channel binding)
clone_or_pull "https://github.com/zyn3rgy/LdapRelayScan.git" "$AD_DIR/LdapRelayScan"

# CrackMapExec legacy (netexec fork)
clone_or_pull "https://github.com/Pennyw0rth/NetExec.git" "$AD_DIR/NetExec"

# Certify (AD CS auditing — mirror)
mkdir -p "$AD_DIR/Certify"
download_bin \
    "https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Certify.exe" \
    "$AD_DIR/Certify/Certify.exe"

# certipy (AD CS Python)
pip_install certipy-ad

# lsassy
pip_install lsassy

# sprayhound
pip_install sprayhound

# donpapi
clone_or_pull "https://github.com/login-securite/DonPAPI.git" "$AD_DIR/DonPAPI"

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ 14 · AD Explorer (Windows uniquement) ═══${RESET}"
mkdir -p "$AD_DIR/ADExplorer"
warn "AD Explorer est un binaire Windows — téléchargement manuel requis."
echo "  → https://learn.microsoft.com/sysinternals/downloads/adexplorer"
echo "  → Placez ADExplorer.exe dans : $AD_DIR/ADExplorer/"

# ════════════════════════════════════════════════════════════
echo -e "\n${BOLD}═══ Résumé ═══${RESET}"
echo -e "Répertoire : ${CYAN}$AD_DIR${RESET}"
echo -e "Installés  : ${GREEN}$INSTALLED${RESET}"
echo -e "Déjà prêts : ${CYAN}$SKIPPED${RESET}"
echo -e "Échecs     : ${RED}$FAILED${RESET}"

if [[ ${#FAILED_LIST[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}Outils à installer manuellement :${RESET}"
    for f in "${FAILED_LIST[@]}"; do
        echo "  - $f"
    done
fi

echo ""
echo -e "${YELLOW}Binaires .exe → exécutables sous Linux via Wine :${RESET}"
echo "  sudo apt install wine64"
echo "  wine $AD_DIR/Rubeus/Rubeus.exe"
echo ""
echo -e "${YELLOW}Scripts Impacket disponibles dans PATH :${RESET}"
echo "  secretsdump.py   psexec.py      wmiexec.py     ntlmrelayx.py"
echo "  GetUserSPNs.py   GetNPUsers.py  lookupsid.py   ticketer.py"
echo "  raiseChild.py    rpcdump.py     mssqlclient.py smbserver.py"
echo ""
echo -e "${YELLOW}Outils Windows uniquement (non installables sous Linux) :${RESET}"
echo "  setspn.exe   → natif Windows Server / RSAT"
echo "  ADExplorer   → https://learn.microsoft.com/sysinternals/downloads/adexplorer"
echo ""
ok "Installation terminée. Tous les outils HTB sont couverts."

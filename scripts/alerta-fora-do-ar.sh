#!/usr/bin/env bash
# Alerta de fora do ar da GIGA RENTAL: roda no GitHub Actions, de FORA do VPS.
# Abre os endereços dos sistemas (todos ao mesmo tempo); quem falha é testado de novo
# mais duas vezes, com 20 s entre as rodadas. Se algum seguir fora, abre UMA issue
# "fora-do-ar" atribuída ao João (o GitHub manda e-mail) dizendo o motivo de cada falha.
# Quando tudo volta, comenta o horário e fecha a issue (outro e-mail). Não repete.
#
# Teste local, sem mexer em nada no GitHub:  SIMULAR=1 GH_REPO=joaogui1991-dev/giga-alerta bash scripts/alerta-fora-do-ar.sh
# ENDERECOS="a b" troca a lista. TESTE=1 junta um endereço que não existe (botão "Simular uma queda").
set -uo pipefail

ROTULO="fora-do-ar"
RESPONSAVEL="${RESPONSAVEL:-joaogui1991-dev}"
RODADAS="${RODADAS:-3}"
ESPERA="${ESPERA:-20}"
DOMINIO="gigarental.com.br"
ENDERECOS="${ENDERECOS:-auth status qg frota manutencao integracao seminovos treinamentos lousa rh juridico compras comercial os marketing}"
export TZ=America/Sao_Paulo
agora=$(date "+%d/%m/%Y %H:%M")
prefixo=""
if [ "${TESTE:-0}" = 1 ]; then
  ENDERECOS="$ENDERECOS teste-do-alerta"
  RODADAS=1
  prefixo="[TESTE] "
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

gh_() {
  if [ "${SIMULAR:-0}" = 1 ]; then echo "  [simulado] gh $*"; else gh "$@"; fi
}

# Grava em $tmp/<nome> "ok" ou o motivo da falha. 2xx e 3xx contam como no ar
# (os módulos mandam para o login do Authelia com 302).
testa() {
  local nome=$1 codigo saida
  codigo=$(curl -s -o /dev/null --connect-timeout 8 -m 12 -w '%{http_code}' "https://$nome.$DOMINIO/" 2>/dev/null)
  saida=$?
  if [[ "$codigo" =~ ^[23][0-9][0-9]$ ]]; then echo ok > "$tmp/$nome"; return; fi
  case $saida in
    0)        echo "o servidor respondeu com erro $codigo" ;;
    6)        echo "DNS: o nome não foi encontrado" ;;
    7)        echo "conexão recusada ou sem rota até o servidor" ;;
    28)       echo "tempo esgotado (o servidor não respondeu)" ;;
    35|60|51) echo "problema no certificado ou na conexão segura (curl $saida)" ;;
    *)        echo "falha de conexão (curl $saida)" ;;
  esac > "$tmp/$nome"
}

pendentes="$ENDERECOS"
for ((r = 1; r <= RODADAS; r++)); do
  for nome in $pendentes; do testa "$nome" & done
  wait
  falhas=""
  for nome in $pendentes; do [ "$(cat "$tmp/$nome")" = ok ] || falhas+="$nome "; done
  pendentes="$falhas"
  [ -z "$pendentes" ] && break
  [ "$r" -lt "$RODADAS" ] && sleep "$ESPERA"
done

fora=()
detalhe=""
so_dns=1
for nome in $ENDERECOS; do
  motivo=$(cat "$tmp/$nome")
  if [ "$motivo" = ok ]; then
    echo "ok    $nome"
  else
    echo "FORA  $nome: $motivo"
    fora+=("$nome")
    detalhe+="- $nome.$DOMINIO: $motivo"$'\n'
    [[ "$motivo" == DNS* ]] || so_dns=0
  fi
done

aberta=$(gh issue list --label "$ROTULO" --state open --json number --jq '.[0].number' 2>/dev/null || true)

if [ "${#fora[@]}" -gt 0 ]; then
  if [ -n "$aberta" ]; then
    echo "Fora do ar, mas o alerta já está aberto (issue #$aberta). Não repete o e-mail."
    exit 0
  fi
  total=$(wc -w <<< "$ENDERECOS" | tr -d ' ')
  if [ "$so_dns" = 1 ]; then
    titulo="Sistema GIGA RENTAL: o DNS não respondeu para ${#fora[@]} de $total endereços ($agora)"
    leitura="Só o DNS falhou: o servidor pode estar no ar, mas quem não tem o endereço guardado não consegue abrir. O DNS do domínio está na UOL (ns1 e ns2.cpuh16, os dois no mesmo IP)."
  elif [ "${#fora[@]}" -ge "$total" ]; then
    titulo="Sistema GIGA RENTAL fora do ar ($agora): nenhum endereço responde"
    leitura="Todos caíram juntos: o problema é no servidor ou na Hostinger, não num módulo. Ver statuspage.hostinger.com (datacenter BR-CAM)."
  else
    titulo="Sistema GIGA RENTAL: ${#fora[@]} endereço(s) fora do ar ($agora)"
    leitura="Só parte caiu: o servidor está no ar, o problema é nesses módulos."
  fi
  corpo="Teste feito de fora do servidor, pelo GitHub, às $agora (horário de Brasília). Quem falhou foi testado $RODADAS vez(es), com $ESPERA s entre as tentativas.

$detalhe
$leitura

Quando tudo voltar, este alerta é fechado sozinho, com o horário da volta."
  [ -n "$prefixo" ] && corpo="Este é um TESTE do alerta: o endereço teste-do-alerta não existe de propósito. O próximo teste agendado fecha esta issue, e chega o e-mail da volta.

$corpo"
  gh_ label create "$ROTULO" --color B60205 --description "Alerta automático de sistema fora do ar" --force > /dev/null
  gh_ issue create --title "$prefixo$titulo" --body "$corpo" --label "$ROTULO" --assignee "$RESPONSAVEL"
  exit 0
fi

if [ -n "$aberta" ]; then
  gh_ issue close "$aberta" --comment "Voltou: todos os endereços respondendo às $agora (horário de Brasília)."
  echo "Tudo de volta; alerta #$aberta fechado."
else
  echo "Tudo no ar."
fi

# giga-alerta

Alerta de fora do ar dos sistemas internos da GIGA RENTAL, testado **de fora** do servidor.

A cada 5 minutos, o GitHub abre os 15 endereços `*.gigarental.com.br`, todos ao mesmo tempo. Quem falha é testado mais duas vezes, com 20 s entre as tentativas. Se algum seguir fora, abre **uma** issue com o rótulo `fora-do-ar` atribuída ao João, e o GitHub manda o e-mail. A issue diz o motivo de cada falha: DNS, conexão, tempo esgotado, certificado ou erro do servidor. Enquanto ela estiver aberta, não repete. Quando tudo volta, comenta o horário da volta e fecha a issue, o que manda o segundo e-mail.

Este repositório é público de propósito: o GitHub não cobra minutos de Actions em repositório público. Não há segredo aqui; só os endereços, que já são públicos.

- Lógica: `scripts/alerta-fora-do-ar.sh`. Teste local sem mexer em nada: `SIMULAR=1 GH_REPO=joaogui1991-dev/giga-alerta bash scripts/alerta-fora-do-ar.sh`.
- Rodar na hora: aba Actions, `Alerta de fora do ar`, `Run workflow`. Marcando `Simular uma queda`, abre uma issue [TESTE] de verdade (para conferir o e-mail); o próximo teste agendado fecha.
- Desligar: aba Actions, `Alerta de fora do ar`, menu `...`, `Disable workflow`.
- O GitHub pode atrasar os agendamentos nos horários cheios.

Criado em 24/10/2026, depois das duas quedas de 23/10/2026 (falta de energia no datacenter BR-CAM da Hostinger). Até então o alerta morava no repositório privado `giga-vps`, onde gastaria a cota de minutos.

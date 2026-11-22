# FPV Racer 0.4 — base executavel

Simulador de carro para celular, em primeira pessoa no cockpit. Referencia de
conducao: Live for Speed. Prioridades: fisica, resposta dos controles e baixo
custo grafico. Destino final: iPhone em `.ipa`. Orcamento para servicos: **R$ 0**.

Esta e a base ativa em **Godot 4.7.2**, que executa sem conta ou ativacao. A base
Unity foi preservada em uma pasta separada; seus testes e resultados nao devem
ser confundidos com os desta versao.

## O que roda

Carro de 1.200 kg, tracao traseira, cambio automatico de cinco marchas e re,
suspensao por roda e barras estabilizadoras. O modelo de pneus usa curvas
analiticas, sensibilidade a carga e limite combinado de forcas longitudinais e
laterais. A rotacao das rodas e integrada em subpassos adaptativos. O chassi usa
as forcas aplicadas nos contatos, sem correcao artificial da orientacao.

ABS, TC e ajuda de direcao sao opcionais. O circuito de treino tem cerca de
636 m, largura de 12 m, grama com aderencia menor, oito checkpoints e tempos
de volta com invalidacao por corte. Melhores tempos e ajustes sao locais.

Ha cockpit, volante animado, controle por toque ou inclinacao, pedais analogicos,
freio de mao, pausa e FOV ajustavel. Motor e pneus usam sons sintetizados no
projeto; nao sao gravacoes de um carro real. Os graficos ainda sao simples.

## Verificacao realizada

- 31 checks de fisica e pneus passaram dentro do Godot.
- 12 checks de eventos de toque, cancelamento, pausa e cronometragem passaram.
- Um piloto automatico de teste, que atua somente nos pedais e na direcao,
  completou duas voltas validas: aproximadamente **40,84 s** e **40,44 s**.
  Velocidade maxima observada: **73,9 km/h**. Desvio lateral maximo em relacao
  ao centro da pista: **1,42 m**, sem sair da pista.
- No ensaio em linha reta: aproximadamente **44,7 km/h em 3 segundos**; o teste
  de frenagem subsequente terminou parado. Re, curva, grama, pausa e reinicio
  tambem passaram. A oscilacao inicial em repouso foi corrigida.
- O cockpit e o menu foram inspecionados em uma janela real. Aceleracao e
  reinicio foram acionados pelo teclado nessa janela.
- O projeto **Xcode foi exportado em Linux** com o template oficial de iOS.
- O instalador de CI para Linux foi executado e seu download oficial teve o
  SHA256 conferido. Os testes tambem passaram em uma copia limpa do codigo,
  sem cache do editor. Os resultados desta entrega estao em `verification.json`.

Esses resultados sao de simulacao e desktop. Ainda faltam compilacao Xcode,
assinatura pessoal, instalacao, desempenho, temperatura, inclinacao e controle
fisico em um iPhone. Nao existe IPA gerado nesta entrega. A meta de 60 FPS e
configuracao, nao uma medicao no aparelho.

## Abrir e verificar

Importe `project.godot` no Godot 4.7.2 e use F5. Nao exige assets pagos ou conta.
Teclado: WASD/setas, espaco para freio de mao, Q para D/R parado, R para reinicio
e P/Esc para pausa. O menu permite ajustar as ajudas, FOV e sensibilidade.
No celular, use dedos diferentes para direcao e pedais; mais alto no pedal
significa maior pressao. A inclinacao e calibrada ao ativar o modo.

Os testes podem ser repetidos com Godot, Bash e ripgrep:

```sh
bash scripts/check.sh
```

## Entrega iOS sem contratar servicos

O preset `iOS Unsigned` gera o projeto Xcode. O Team ID `0000000000` e apenas
um valor de configuracao para esse export, sem conta Apple ou certificado.
`scripts/build-ios-unsigned.sh` exporta o projeto em Linux; em macOS com Xcode,
tambem compila com assinatura desabilitada e empacota `FPVRacer-unsigned.ipa`.
Um IPA sem assinatura **nao instala diretamente**.
O template oficial de Godot 4.7.2 exige o SDK de iOS 26 ou posterior na
compilacao; o workflow seleciona Xcode 26.3, em vez do Xcode 16.4 padrao do runner.

O workflow `.github/workflows/ios-free.yml` foi preparado para runners padrao
gratuitos em repositorio publico. Primeiro verifica a simulacao em Linux,
depois compila em macOS e guarda o arquivo em um release de rascunho. O fluxo
nao usa armazenamento de artifacts do Actions. A execucao remota e a compilacao
macOS ainda estao pendentes. O workflow inicia ao enviar alteracoes do jogo
para `main`, ou manualmente na aba Actions. O log de uma etapa com falha e
exibido no CI, preservando o codigo de erro do Godot ou do Xcode.

A etapa macOS do script continua sem verificacao real neste ambiente Linux.
Para teste pessoal, ferramentas gratuitas de sideload no Windows podem assinar
com Apple ID gratuito, com renovacao em sete dias. A disponibilidade de um
computador para essa instalacao ainda precisa ser confirmada. Nao prometer
publicacao na App Store ou instalacao permanente gratuita.

O motor Godot usa a licenca MIT incluida em `GODOT-LICENSE.txt`. O codigo do
jogo e original deste projeto; esta entrega nao define uma licenca publica para ele.

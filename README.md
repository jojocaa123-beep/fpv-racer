# FPV Racer 0.9 — marchas manuais, mapa e indicacao de curvas

Simulador de carro para celular, em primeira pessoa no cockpit. Referencia de
conducao: Live for Speed. Prioridades: fisica, resposta dos controles e baixo
custo grafico. Destino final: iPhone em `.ipa`. Orcamento para servicos: **R$ 0**.

Esta e a base ativa em **Godot 4.7.2**, que executa sem conta ou ativacao. A base
Unity foi preservada em uma pasta separada; seus testes e resultados nao devem
ser confundidos com os desta versao.

## O que roda

Carro de 1.200 kg, tracao traseira, cambio de cinco marchas e re,
com modos automatico e manual sequencial,
suspensao por roda e barras estabilizadoras. O modelo de pneus usa curvas
analiticas, sensibilidade a carga e limite combinado de forcas longitudinais e
laterais. A rotacao das rodas e integrada em subpassos adaptativos. O chassi usa
as forcas aplicadas nos contatos, sem correcao artificial da orientacao.

ABS, TC e ajuda de direcao sao opcionais. O circuito de treino tem cerca de
636 m, largura de 12 m, grama com aderencia menor, oito checkpoints e tempos
de volta com invalidacao por corte. Melhores tempos e ajustes sao locais.

O modo inicial de cambio continua automatico. A opcao CAMBIO no menu permite
selecionar manual sequencial: botoes + SUBIR / - REDUZIR na tela ou E / C no PC.
Cada toque troca uma unica marcha, mantendo os outros dedos na direcao e pedais.
O jogo interrompe o torque por 0,22 s durante a troca. Reducoes que levariam o
motor acima de 6.700 rpm sao recusadas, considerando tambem a velocidade do
chassi quando as rodas estao travadas. O limitador continua ativo em manual.

O mapa mostra a pista completa, a largada, sua posicao e a posicao do fantasma.
O aviso de curva indica sentido e distancia aproximada, calculados a partir da
geometria do circuito. MAPA E CURVAS no menu permite esconder esses elementos;
essa escolha e o modo de cambio ficam salvos.

O treino agora tem tres setores e comparacao de tempo com a melhor volta gravada.
O delta e estimado no mesmo ponto do circuito, usando projecao entre checkpoints
ordenados: negativo indica vantagem, positivo indica atraso. O fantasma
translucido reproduz a posicao e orientacao dessa volta, com interpolacao entre
amostras de 20 Hz. Ele desaparece perto do piloto para deixar o para-brisa livre.
A opcao FANTASMA no menu fica salva; o delta e a gravacao continuam disponiveis.

Somente voltas validas completas substituem a gravacao, quando sao mais rapidas.
Cortes, reinicios e tentativas mais lentas preservam a referencia. A gravacao local
usa arquivo JSON com substituicao atomica, identificador de circuito e limites de
tamanho e duracao (10 minutos). Tempos antigos continuam preservados; a referencia
visual precisa de uma volta gravada a partir desta versao. Nao ha uma volta
preenchida artificialmente na primeira abertura.

A direcao por movimento e o modo inicial no iPhone: giroscopio e gravidade
combinados, calibracao do neutro, zona morta e sensibilidade ajustavel. O botao
GIROSCOPIO / SETAS / DESLIZAR fica visivel durante a pilotagem. Setas esquerda e
direita tambem funcionam como controle manual no modo de movimento. Soltar ou
cancelar um toque libera a direcao. Setas opostas se anulam.

O cockpit tem velocimetro e conta-giros com ponteiros ligados a simulacao,
indicador de marcha, luzes de troca e volante de tres raios animado. Console,
saidas de ar e estrutura da cabine foram detalhados. O HUD de velocidade fica
no topo para liberar a vista dos instrumentos. Ha pedais analogicos, freio de
mao, pausa e FOV ajustavel, com setas e calibracao visiveis.

A pista ganhou texturas procedurais de asfalto e grama, zebras continuas,
guard-rails com colisao, placas de 100/50 metros antes das curvas e portico
de largada. Arvores e colinas formam o entorno, com ceu procedural, neblina
suave e sombras do sol. Guard-rails, arvores e zebras usam lotes MultiMesh.
Os elementos e materiais sao gerados pelo projeto, sem assets pagos.
A camera acompanha suavemente a aceleracao, frenagem e curvas, com deslocamento
limitado dentro da cabine. O menu permite trocar para camera fixa. O medidor G
usa a aceleracao do chassi e o indicador dos quatro pneus mostra contato e
deslizamento; suas cores nao representam temperatura. Derrapagens no asfalto
deixam marcas, em um lote limitado a 512 segmentos.

O menu foi reorganizado em duas colunas. Tres niveis graficos ficam salvos:
economico (escala 3D de 75%, sem sombras ou MSAA), equilibrado (85%, sombras
ate 70 m e MSAA 2x) e alto (100%, sombras ate 110 m e MSAA 4x). O HUD continua
na resolucao da interface. O modo inicial e equilibrado; esses ajustes ainda
nao foram medidos em um iPhone real.

Motor e pneus usam sons sintetizados no projeto; nao sao gravacoes de um carro real. Os graficos ainda sao simples.

## Verificacao realizada

- 31 checks de fisica e pneus passaram dentro do Godot.
- 22 checks de eventos de toque, setas, cancelamento, pausa e cronometragem passaram.
- 15 checks do filtro de movimento passaram com leituras simuladas: sentido,
  calibracao, tremor, deriva, perda do sensor, celular em pe ou deitado e
  taxas de 30, 60 e 120 Hz.
  O sensor fisico do iPhone ainda precisa de verificacao no aparelho.
- 14 checks de aceleracao medida, camera a 30/60/120 Hz, limites em impactos,
  frenagem real, marcas de pneu, toques nas opcoes graficas e preferencias passaram.
- 21 checks de gravacao/reproducao, delta, setores, persistencia, arquivos
  danificados, tentativas invalidas e toque na opcao FANTASMA passaram.
- 25 checks de marchas, limitador, reducoes seguras, torque durante a troca,
  toques simultaneos, teclado, preferencias e geometria do mapa/curvas passaram.
- Um piloto automatico de teste, que atua somente nos pedais e na direcao,
  completou duas voltas validas: aproximadamente **40,84 s** e **40,44 s**.
  Velocidade maxima observada: **73,9 km/h**. Desvio lateral maximo em relacao
  ao centro da pista: **1,42 m**, sem sair da pista. A melhor volta gerou
  810 amostras, com setores de 16,015 s, 10,349 s e 14,079 s.
- O piloto tambem completou duas voltas validas em manual, solicitando
  cada troca: **40,825 s** e **40,423 s**, com desvio lateral maximo de **1,42 m**.
- No ensaio em linha reta: aproximadamente **44,7 km/h em 3 segundos**; o teste
  de frenagem subsequente terminou parado. Re, curva, grama, pausa e reinicio
  tambem passaram. A oscilacao inicial em repouso foi corrigida.
- O cockpit e o menu foram inspecionados em uma janela real. Aceleracao e
  reinicio foram acionados pelo teclado nessa janela.
- O novo cockpit e o circuito foram renderizados em 1280 x 720 e inspecionados,
  parado e em movimento a cerca de 70 km/h, com ponteiros, marcha e luzes ativos.
- O HUD de pneus/forca G e o menu foram inspecionados no renderizador GL
  Compatibility. O renderizador mobile nao iniciou neste ambiente Linux por
  falta de uma extensao Vulkan; a conferencia de Metal no iPhone esta pendente.
- O fantasma, o delta e um setor concluido foram conferidos na imagem real
  renderizada em desktop. O renderizador Metal e os sensores do iPhone seguem
  pendentes de teste no aparelho.
- O cambio manual, mapa, seta de curva e menu foram conferidos em capturas
  reais do jogo no desktop.
- O iOS 0.9 foi compilado com Xcode 26.3 / SDK iOS 26.2. O IPA passou na
  verificacao de ZIP, Info.plist, executavel arm64 e presenca dos modulos de
  direcao, feedback, fantasma, cambio, mapa e indicacao de curva no pacote.
- As 128 verificacoes, quatro voltas e compilacao iOS passaram no
  [build 9](https://github.com/jojocaa123-beep/fpv-racer/actions/runs/45702837738).
- O instalador de CI para Linux foi executado e seu download oficial teve o
  SHA256 conferido. Os testes tambem passaram em uma copia limpa do codigo,
  sem cache do editor. Os resultados desta entrega estao em `verification.json`.

A simulacao e os controles da versao 0.9 foram verificados em desktop.
Ainda faltam assinatura pessoal, instalacao, desempenho, temperatura,
inclinacao e controle fisico em um iPhone. O IPA de desenvolvimento requer assinatura pessoal para instalar.
A meta de 60 FPS e configuracao, nao uma medicao no aparelho.

## Abrir e verificar

Importe `project.godot` no Godot 4.7.2 e use F5. Nao exige assets pagos ou conta.
Teclado: WASD/setas, espaco para freio de mao, Q para D/R parado, R para reinicio
e P/Esc para pausa; E/C sobem/reduzem marchas no modo manual. O menu permite ajustar as ajudas, FOV e sensibilidade.
No celular, use dedos diferentes para direcao e pedais; mais alto no pedal
significa maior pressao. No iPhone o modo de movimento calibra a primeira
leitura valida. Segure o aparelho na posicao de pilotagem e toque CALIBRAR para
redefinir o neutro. Toque no nome do modo para alternar para SETAS ou DESLIZAR.

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
nao usa armazenamento de artifacts do Actions. O historico de verificacao e os
resultados da versao atual estao em `verification.json`. O runner atual e o
[macos-15-intel padrao](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
gratuito em repositorios publicos.
O workflow inicia ao enviar alteracoes do jogo
para `main`, ou manualmente na aba Actions. O log de uma etapa com falha e
exibido no CI, preservando o codigo de erro do Godot ou do Xcode.

Cada IPA gerado fica em um release de rascunho, acessivel ao dono do repositorio.
A versao 0.9 desta entrega esta no release `ios-9-1`.
Para teste pessoal, ferramentas gratuitas de sideload no Windows podem assinar
com Apple ID gratuito, com renovacao em sete dias. O dispositivo informado para a
validacao e um iPhone 14, com acesso a PC Windows 10/11. Nao prometer
publicacao na App Store ou instalacao permanente gratuita.

O motor Godot usa a licenca MIT incluida em `GODOT-LICENSE.txt`. O codigo do
jogo e original deste projeto; esta entrega nao define uma licenca publica para ele.

extends SceneTree

const Motion = preload("res://ui/motion_steering.gd")
var checks: int = 0
var failed: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func gravity(degrees: float) -> Vector3:
	var angle: float = deg_to_rad(degrees)
	return Vector3(sin(angle), -cos(angle), 0)*9.81

func settle(model, degrees: float, frames: int = 60, rate: float = 60.0) -> float:
	for i in frames:
		model.step(1.0/rate, gravity(degrees), Vector3.ZERO, 2.5)
	return model.value

func _initialize() -> void:
	var model = Motion.new()
	check(model.step(1.0/60, Vector3.ZERO, Vector3.ZERO, 2.5) == 0 and not model.ready, "Sensor ausente nao inventa direcao")
	settle(model, 8)
	check(model.ready and absf(model.value) < 0.001, "Primeira leitura calibra a posicao de pilotagem")
	settle(model, 28)
	check(model.value > 0.55 and model.value < 0.7, "Inclinar vinte graus para direita gera comando proporcional")
	settle(model, -12)
	check(model.value < -0.55 and model.value > -0.7, "Inclinar vinte graus para esquerda gera comando proporcional")
	settle(model, 75)
	check(model.value > 0.99 and model.value <= 1.0, "Comando permanece limitado em inclinacao extrema")
	model.calibrate()
	settle(model, 12)
	check(absf(model.value) < 0.001, "Recalibracao remove o angulo anterior")
	for i in 120:
		model.step(1.0/60, gravity(12+sin(i*0.7)*0.7), Vector3.ZERO, 2.5)
	check(absf(model.value) < 0.01, "Zona morta absorve pequenas tremidas em repouso")
	model.calibrate()
	settle(model, 0)
	for i in 6:
		model.step(1.0/60, gravity(0), Vector3(0, 0, -2.0), 2.5)
	check(model.value > 0.06, "Giroscopio antecipa resposta antes de a gravidade estabilizar")
	settle(model, 0, 240)
	check(absf(model.value) < 0.001, "Referencia de gravidade corrige deriva do giroscopio")
	settle(model, 30)
	for i in 30:
		model.step(1.0/60, Vector3.ZERO, Vector3(0, 0, -1), 2.5)
	check(not model.ready and absf(model.value) < 0.001, "Perder referencia libera a direcao com seguranca")
	var output: Array[float] = []
	for rate in [30.0, 60.0, 120.0]:
		var sample = Motion.new()
		settle(sample, 0, 1, rate)
		for i in int(rate):
			var degrees: float = 20.0*(i+1)/rate
			sample.step(1.0/rate, gravity(degrees), Vector3(0, 0, -deg_to_rad(20)), 2.5)
		output.append(sample.value)
	check(absf(output[0]-output[2]) < 0.025, "Resposta consistente em trinta, sessenta e cento e vinte Hz")
	model.calibrate()
	settle(model, 179)
	settle(model, -161)
	check(model.value > 0.55 and model.value < 0.7, "Filtro atravessa a fronteira angular sem inverter o volante")
	print("RESULT checks=", checks, " failed=", failed)
	quit(0 if failed == 0 else 1)

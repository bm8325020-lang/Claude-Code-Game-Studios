# Texturas da casa americana (05/11, RAVEN CREEK): feitas por código (nossas). Claras e neutras: a cor de cada casa vem da
# tinta do material no jogo (Bairro._mat_ruina). Grava cor + normal em assets/texturas:
#   python3 tools/texturas/gera_americanas.py
import numpy as np
from PIL import Image, ImageFilter

R = np.random.default_rng(11)
N = 512


def ruido(escala, n=N):
    p = max(2, n // escala)
    return np.array(Image.fromarray((R.random((p, p)) * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)) / 255.0


def normal(alt, forca=2.5, borra=1.0):
    a = np.array(Image.fromarray((np.clip(alt, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(borra))) / 255.0
    gx = (np.roll(a, -1, 1) - np.roll(a, 1, 1)) * forca
    gy = (np.roll(a, -1, 0) - np.roll(a, 1, 0)) * forca
    n = np.dstack([-gx, gy, np.ones_like(a)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def grava(nome, cor, alt, forca=2.5):
    Image.fromarray((np.clip(cor, 0, 1) * 255).astype(np.uint8)).save("assets/texturas/%s_cor.jpg" % nome, quality=88)
    Image.fromarray(normal(alt, forca)).save("assets/texturas/%s_normal.jpg" % nome, quality=92)


y, x = np.mgrid[0:N, 0:N]

# siding: 8 tábuas horizontais sobrepostas (lap siding), sombra embaixo de cada uma, veio leve, tinta gasta
tab = N / 8
f = (y % tab) / tab                       # 0 no topo da tábua, 1 embaixo
veio = ruido(4)[:, :] * 0.5 + np.sin(x / 9.0 + ruido(16) * 6) * 0.04
base = 0.9 - 0.05 * veio - 0.12 * f ** 3   # escurece na beira de baixo (sombra da sobreposição)
base -= (f > 0.93) * 0.35                  # linha da sobreposição
base -= ruido(4) * 0.04  # tinta gasta, fina
cor = np.dstack([base, base * 0.99, base * 0.97])
grava("siding", cor, 1 - f * 0.7 - (f > 0.93) * 0.3, 3.0)

# shingle: fileiras de telha asfáltica com abas desencontradas, grão de areia
fil = N / 10
fy = (y % fil) / fil
lin = (y // fil).astype(int)
aba = N / 6
fx = ((x + (lin % 2) * aba / 2) % aba) / aba
tom = R.uniform(-0.06, 0.06, (12, 8))[lin % 12, ((x + (lin % 2) * aba / 2) // aba).astype(int) % 8]
grao = R.random((N, N)) * 0.12
b = 0.55 + tom - grao - 0.25 * (fy > 0.86) - 0.2 * (np.minimum(fx, 1 - fx) < 0.015)
cor = np.dstack([b, b * 0.98, b * 0.96])
grava("shingle", cor, 1 - fy * 0.5 - (fy > 0.86) * 0.4 - (np.minimum(fx, 1 - fx) < 0.015) * 0.3 + grao, 2.0)

# carpete: fibra fina e manchas de pisada
fibra = R.random((N, N))
b = 0.78 - fibra * 0.12 - ruido(8) * 0.05 - ruido(3) * 0.04
grava("carpete", np.dstack([b, b * 0.97, b * 0.93]), fibra * 0.6 + 0.2, 1.2)

# linóleo: placas 30 cm quadriculadas (cozinha/lavanderia), riscos e sujeira
n = 4
ix, iy = (x // (N / n)).astype(int), (y // (N / n)).astype(int)
xadrez = (ix + iy) % 2
b = np.where(xadrez == 1, 0.9, 0.7) - ruido(6) * 0.04 + R.uniform(-0.02, 0.02, (N, N))
junta = (np.minimum((x % (N / n)) / (N / n), 1 - (x % (N / n)) / (N / n)) < 0.006) | \
        (np.minimum((y % (N / n)) / (N / n), 1 - (y % (N / n)) / (N / n)) < 0.006)
b = np.where(junta, b * 0.7, b)
grava("linoleo", np.dstack([b, b * 0.98, b * 0.94]), np.where(junta, 0.3, 1.0), 1.5)

# portão de garagem: 4 painéis horizontais com 2 sulcos, chapa clara
pan = N / 4
fp = (y % pan) / pan
b = 0.86 - ruido(32) * 0.06 - 0.25 * (fp > 0.95) - 0.12 * ((np.abs(fp - 0.33) < 0.012) | (np.abs(fp - 0.66) < 0.012))
grava("garagem", np.dstack([b, b, b * 0.98]), 1 - (fp > 0.95) * 0.6 - 0.3 * ((np.abs(fp - 0.33) < 0.012) | (np.abs(fp - 0.66) < 0.012)), 3.0)
print("ok")

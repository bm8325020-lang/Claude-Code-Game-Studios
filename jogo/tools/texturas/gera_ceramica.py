# Texturas de azulejo (parede) e cerâmica (piso) feitas por código (31/10, dono: "dentro tem que ter piso, cerâmica e
# cores"): placas claras com rejunte, sujeira leve; mapa normal com o sulco do rejunte. Grava em assets/texturas:
#   python3 tools/texturas/gera_ceramica.py
import numpy as np
from PIL import Image, ImageFilter

R = np.random.default_rng(7)
N = 512


def placas(n, rejunte, base, var, sujeira):
    """n placas por lado; devolve (cor RGB uint8, altura 0..1)."""
    y, x = np.mgrid[0:N, 0:N]
    passo = N / n
    fx, fy = (x % passo) / passo, (y % passo) / passo
    junta = (np.minimum(fx, 1 - fx) < rejunte) | (np.minimum(fy, 1 - fy) < rejunte)
    ix, iy = (x // passo).astype(int), (y // passo).astype(int)
    tom = R.uniform(-var, var, (n, n))[iy, ix]
    ruido = np.array(Image.fromarray((R.random((N // 8, N // 8)) * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)) / 255.0
    cor = np.zeros((N, N, 3))
    for c in range(3):
        cor[..., c] = base[c] + tom - sujeira * ruido
    cor[junta] = np.array(base) * 0.62 - 0.05
    alt = np.where(junta, 0.0, 1.0)
    return (np.clip(cor, 0, 1) * 255).astype(np.uint8), alt


def normal(alt, forca=2.5):
    a = np.array(Image.fromarray((alt * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))) / 255.0
    gx = (np.roll(a, -1, 1) - np.roll(a, 1, 1)) * forca
    gy = (np.roll(a, -1, 0) - np.roll(a, 1, 0)) * forca
    n = np.dstack([-gx, gy, np.ones_like(a)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


for nome, (n, rej, base, var, suj) in {"azulejo": (6, 0.035, (0.93, 0.93, 0.9), 0.03, 0.08),
                                       "ceramica": (3, 0.018, (0.86, 0.82, 0.74), 0.04, 0.12)}.items():
    cor, alt = placas(n, rej, base, var, suj)
    Image.fromarray(cor).save("assets/texturas/%s_cor.jpg" % nome, quality=88)
    Image.fromarray(normal(alt)).save("assets/texturas/%s_normal.jpg" % nome, quality=92)
print("ok")

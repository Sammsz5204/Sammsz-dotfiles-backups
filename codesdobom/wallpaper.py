escurecer_imagem("/home/sam/.Wallpapers/wallhaven.jpg", "/home/sam/.config/hypr/wall.jpg", 0.5)

    try:
        # Abre a imagem
        img = Image.open(caminho_entrada)
        
        # Cria um objeto para ajustar o brilho
        enhancer = ImageEnhance.Brightness(img)
        
        # Escurece a imagem
        img_escura = enhancer.enhance(fator_escurecimento)
        
        # Cria o diretório de saída se não existir
        os.makedirs(os.path.dirname(caminho_saida), exist_ok=True)
        
        # Salva a imagem escurecida
        img_escura.save(caminho_saida)
        
        print(f"✓ Imagem escurecida salva em: {caminho_saida}")
        
    except FileNotFoundError:
        print(f"✗ Erro: Arquivo não encontrado - {caminho_entrada}")
    except Exception as e:
        print(f"✗ Erro ao processar imagem: {str(e)}")


def processar_diretorio(dir_entrada, dir_saida, fator_escurecimento=0.5):
    """
    Processa todas as imagens de um diretório.
    
    Parâmetros:
    - dir_entrada: diretório com as imagens originais
    - dir_saida: diretório para salvar as imagens escurecidas
    - fator_escurecimento: valor entre 0 e 1
    """
    # Extensões de imagem suportadas
    extensoes = ('.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff')
    
    # Lista todos os arquivos no diretório
    arquivos = [f for f in os.listdir(dir_entrada) 
                if f.lower().endswith(extensoes)]
    
    if not arquivos:
        print(f"Nenhuma imagem encontrada em {dir_entrada}")
        return
    
    print(f"Processando {len(arquivos)} imagem(ns)...\n")
    
    for arquivo in arquivos:
        caminho_entrada = os.path.join(dir_entrada, arquivo)
        caminho_saida = os.path.join(dir_saida, arquivo)
        escurecer_imagem(caminho_entrada, caminho_saida, fator_escurecimento)


# Exemplo de uso
if __name__ == "__main__":
    # Aqui os diretórios
    DIRETORIO_ENTRADA = "./imagens_originais"
    DIRETORIO_SAIDA = "./imagens_escuras"
    
    # Fator de pretidaoKKKKKKKJ
    FATOR = 0.5
    
    # Processa todas as imagens do diretório
    processar_diretorio(DIRETORIO_ENTRADA, DIRETORIO_SAIDA, FATOR)

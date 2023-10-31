import heic2any from "heic2any";

export function heicConvert(file, type = "image/png", quality = 0.5) {
  return heic2any({
    blob: file,
    toType: type,
    quality: quality,
  });
}

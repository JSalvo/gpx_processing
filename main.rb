require 'nokogiri'
require 'time'
require 'gruff'

risoluzione_immagine_output = 6000


# Creo un nuovo Grafico Gruff!!! :))
g = Gruff::Line.new(risoluzione_immagine_output)
# Titolo del grafico
g.title = 'Dislivello'
g.hide_dots = true

# A causa dell'imprecisione con cui viene rilevato un punto (+- 10m), il guadagno
# orario in m di quota, non è corretto. Bisogna mediare il guadagno orario di quota
# per alcuni punti (in questo caso 60)
def get_data(nome_file, intervallo_media = 60)
  # Apro in lettura, il file xml con suffisso "nome_file". Uso Nokogiri per processarlo
  doc = Nokogiri::XML(File.open("/home/gianmario/Desktop/Git/gpx_processing/tests/input/#{nome_file}.gpx"));

  dati_grafico = []

  # Cerco la sezione taggata come trkseg (ce ne può essere più di una)
  doc.search("trkseg").each do |segment|

    prev_elevation = nil
    prev_time = nil

    # Ciascun elemento  di trkseg è un punto
    segment.elements.each do |point|
      # Recupero la quota altimetrica del punto (e la converto in formato float)
      elevation = point.search("ele")[0].content.to_f
      # Recupero il tempo di passaggio nel dato punto
      current_time = Time.parse(point.search("time")[0].content)

      if prev_elevation
        # Calcolo il dislivello tra il punto corrente e il precedente
        delta_elevation = elevation - prev_elevation

        # Calcolo il tempo trascorso tra il punto corrente e il punto precedente
        delta_time = current_time - prev_time

        # Stampo i metri orari (in verticale) percorsi tra il punto corrente e quello precedente
        p (delta_elevation / delta_time) * 3600

        # Inserisco il valore sopra stampato, nell'array che poi verrà "filtrato"
        dati_grafico.append((delta_elevation / delta_time) * 3600)
      end

      # Il punto corrente, diventa il punto precedente per il "prossimo giro"
      prev_elevation = elevation
      prev_time = current_time
    end
  end


  # La media mobile applicata sull'array dati grafico, è una sorta di filtro che
  # elimina le "alte frequenze" e che va quindi ad ottenere un grafico "smussato"
  # che presenta valori più attendibili
  array_filtrato = []
  (0...(dati_grafico.size - intervallo_media)).each do |i|
      v = 0
      (i...(i+intervallo_media)).each do |j|
        v += dati_grafico[j]
      end
      v /= intervallo_media * 1.0
      array_filtrato.append(v)
  end

  array_filtrato
end


nome_file_output = "verso_il_garibaldi"

dati_marco = get_data("marco")
dati_gianmario = get_data("arsio3")
dati_arsio = get_data("arsio2")
dati_arsio4 = get_data("arsio4")
dati_ossimo = get_data("ossimo")
dati_temu = get_data("temu")


# Disegno l'array filtrato, che rappresenta il grafico del guadagno orario (espresso in m/h)
# di quota
g.colors = ["red"]

etichette = {}
(0...20).each do |i|
  etichette[i*100] = i.to_s
end
g.labels = etichette





g.data :Garibaldi, dati_temu

g.write("/home/gianmario/Desktop/Git/gpx_processing/tests/output/#{nome_file_output}.png")

require 'nokogiri'
require 'time'
require 'gruff'

risoluzione_immagine_output = 6000


# Creo un nuovo Grafico Gruff!!! :))
g = Gruff::Line.new(risoluzione_immagine_output)
# Titolo del grafico
g.title = 'Dislivello'
g.hide_dots = true



def get_distance(lat1, lon1, lat2, lon2)
  r = 6371000 # Raggio della terra
  
  phi1 = lat1 * (Math::PI / 180.0)
  phi2 = lat2 * (Math::PI / 180.0)

  lambda1 = lon1 * (Math::PI / 180.0)
  lambda2 = lon2 * (Math::PI / 180.0)

  delta_phi = phi2 - phi1
  delta_lambda = lambda2 - lambda1

  a = Math::sin(delta_phi / 2.0)**2 + Math::cos(phi1) * Math::cos(phi2) * Math::sin(delta_lambda/2.0)**2
  c = 2 * Math::asin(Math::sqrt(a))
  d = r * c
end

def get_media(p1, p2)
  


end


def seconds_to_time_string(ss)
  h = ss / 60 / 60
  m = (ss / 60) % 60
  s = ss % 60
  
  h = (h.to_s.size == 1 ? "0" : "") + h.to_s
  m = (m.to_s.size == 1 ? "0" : "") + m.to_s
  s = (s.to_s.size == 1 ? "0" : "") + s.to_s
  
  "#{h}:#{m}:#{s}"
end

def heart_rate_zones(data)
  total_time = (data.last[:time] - data.first[:time]).to_i

  z1 = 0
  z2 = 0
  z3 = 0
  z4 = 0
  z5 = 0

  data.each do |datum|
    if datum[:hr] < 139 
      z1 += 1
    elsif datum[:hr] < 154 
      z2 += 1
    elsif datum[:hr] < 172 
      z3 += 1
    elsif datum[:hr] < 184 
      z4 += 1
    else
      z5 += 1
    end  
  end

  p "Total Time:"
  p seconds_to_time_string(total_time)
  p ""

  p "Zone 5 > 184 bpm - Maximum"
  p seconds_to_time_string(z5) + " " + ((z5/total_time.to_f) * 100).to_i.to_s + "%"
  p ""

  p "Zone 4 172 - 183 bpm - Threshold"
  p seconds_to_time_string(z4) + " " + ((z4/total_time.to_f) * 100).to_i.to_s + "%"
  p ""

  p "Zone 3 154 - 171 bpm - Aerobic"
  p seconds_to_time_string(z3) + " " + ((z3/total_time.to_f) * 100).to_i.to_s + "%"
  p ""

  p "Zone 2 139 - 153 bpm - Easy"
  p seconds_to_time_string(z2) + " " + ((z2/total_time.to_f) * 100).to_i.to_s + "%"
  p ""

  p "Zone 1 < 123 bpm - Warm up"
  p seconds_to_time_string(z1) + " " + ((z1/total_time.to_f) * 100).to_i.to_s + "%"
  p ""
 
  total_time
end

def cumulative_elevations(data)
  dp = 0
  dm = 0
  
  step = 10

  (0...(data.size-1)).step(step).each do |i|
    delta = (data[i+step] ? data[i+step][:elevation] : data.last[:elevation]) - data[i][:elevation]

    if delta > 0
      dp += delta
    else
      dm -= delta
    end
  end
  p "D+ #{dp.to_i} m / D- #{dm.to_i} m"
end



# I punti gps, sono rilevati a intervalli temporali non costanti. 
# - Creo dei punti fittizi per interpolazione, in modo da avere punti ogni secondo.
# - "Riempio i buchi" nella traccia cardio, utilizzando la lettura precedente
def normalize_data(data)
  result = []

  # A volte il cardio perde il segnale e viene registrato un battito nullo. Se la prima lettura del battito è nulla, la imposto a 30.  
  if data[0][:hr] < 30
    data[0][:h4] = 30
  end

  i = 0
  while i < (data.size - 1)
    # A volte, il cardio perde il segnale e viene registrato un battito nullo. Se la lettura i+1 del cardio è nulla, la imposto alla lettura i
    # In questo modo "riempio i buchi" ed evito che nel grafico del cardio, appaiono dei drop.
    if data[i+1][:hr] < 30
      data[i+1][:hr] = data[i][:hr]
    end

    delta_time = (data[i+1][:time] - data[i][:time]).to_f    
    delta_position =  [(data[i+1][:position][:lat] - data[i][:position][:lat] / delta_time), (data[i+1][:position][:lon] - data[i][:position][:lon] / delta_time) ]
    delta_elevation = (data[i+1][:elevation] - data[i][:elevation]) / delta_time
    delta_hr = (data[i+1][:hr] - data[i][:hr]) / delta_time
    
    (0...delta_time.to_i).each do |j|      
      result << {
        position: {
          lat: data[i][:position][:lat] + delta_position[0]*j,
          lon: data[i][:position][:lon] + delta_position[1]*j
        },
        elevation: data[i][:elevation] + delta_elevation * j,
        time: data[i][:time] + j,
        hr: data[i][:hr] + j * delta_hr,
      }    
    end  

    i += 1
  end

  result
end


def get_data_array(data)
  result = []
  data.each_with_index do |element, idx|
    if idx > 0
      result << (data[idx][:time] - data[idx-1][:time])
    end
  end

  result
end

def get_times(data)
  data.inject([]) {|acc, e| acc << e[:time]}
end

def get_cardio_frequencies(data)
  result = data.inject([]) {|acc, e| acc << e[:hr]}

  (1...result.size).each do |i|
    if result[i] < 30
      result[i] = result[i-1]
    end
  end

  result
end

def get_elevations(data)
  data.inject([]) {|acc, e| acc << e[:elevation]}
end


# A causa dell'imprecisione con cui viene rilevato un punto (+- 10m), il guadagno
# orario in m di quota, non è corretto. Bisogna mediare il guadagno orario di quota
# per alcuni punti (in questo caso 60)
def get_data(file_name, intervallo_media = 60)
  # Apro in lettura, il file xml file_name. Uso Nokogiri per processarlo
  doc = Nokogiri::XML(File.open(file_name));
  doc.remove_namespaces! 

  dati_grafico = []

  last_point = []
  last_time = nil
  total_distance = 0

  data = []

  # Cerco la sezione taggata come trkseg (ce ne può essere più di una)
  doc.search("trkseg").each do |segment|
    

    prev_elevation = nil
    prev_time = nil


    
    # Ciascun elemento  di trkseg è un punto
    segment.elements.each_with_index do |point, idx|
      lat = point.attribute('lat').to_s.to_f
      lon = point.attribute('lon').to_s.to_f


      if idx > 0
        d = get_distance(last_point[0], last_point[1], lat, lon)
        delta_t = Time.parse(point.search("time")[0].content) - last_time
        #p "Distanza: #{d}"

        if d > 1 
          last_point = [lat, lon]
          last_time = Time.parse(point.search("time")[0].content)

          #p "Velocità: #{((d / delta_t.to_f)*3600)/1000.0} Km/h" 
          cardio = point.search('extensions')[0].search('hr')[0] ? point.search('extensions')[0].search('hr')[0].content : "n/a"
          #p "Cardio: #{cardio} bpm"

          total_distance += d
        end

      else
        last_point = [lat, lon]
        last_time = Time.parse(point.search("time")[0].content)

      end

      # Recupero la quota altimetrica del punto (e la converto in formato float)
      elevation = point.search("ele")[0].content.to_f
      # Recupero il tempo di passaggio nel dato punto
      current_time = Time.parse(point.search("time")[0].content)

      data << {
        position: {
          lat: lat,
          lon: lon
        },
        elevation: elevation,
        time: current_time, # secondi
        hr: (point.search('extensions')[0].search('hr')[0] ? point.search('extensions')[0].search('hr')[0].content.to_i : 0)
      }

      if prev_elevation
        # Calcolo il dislivello tra il punto corrente e il precedente
        delta_elevation = elevation - prev_elevation

        # Calcolo il tempo trascorso tra il punto corrente e il punto precedente
        delta_time = current_time - prev_time

        # Stampo i metri orari (in verticale) percorsi tra il punto corrente e quello precedente
        #p (delta_elevation / delta_time) * 3600

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

  array_filtrato = []

  (0...dati_grafico.size).step(intervallo_media).each do |i|
    dati_da_mediare = dati_grafico[i..(i+intervallo_media-1)]
    dimensione_dati_da_mediare = dati_da_mediare.size

    dato_mediato = (dati_da_mediare.sum / dimensione_dati_da_mediare.to_f)

    dato_mediato

    array_filtrato = array_filtrato + ([dato_mediato]*dimensione_dati_da_mediare)
  end


  times = get_data_array(data)

  array_filtrato  
  normalize_data(data)
end

def media_data(data, step)
  result = []

  (0...(data.size - step)).each do |i|
    v = 0
    (i...(i+step)).each do |j|
      v += data[j]
    end
    v /= step * 1.0
    result << v
  end

  result
end

def average_data(data, media_interval = 60)
  result = []
  data.each_slice(media_interval) do |slice|
    last = slice.last
    avg_elevation = slice.sum { |d| d[:elevation].to_f } / slice.size
    avg_hr = slice.sum { |d| d[:hr].to_f } / slice.size

    result << {
      position: {
        lat: last[:position][:lat],
        lon: last[:position][:lon]
      },
      elevation: avg_elevation,
      time: last[:time],
      hr: avg_hr
    }
  end
  result
end


# Argomenti 
first_arg, *the_rest = ARGV

# Bisogna specificare il nome di un file GPX
if first_arg.nil?
    p "Devi fornire il nome di un file gpx, come argomento"

else

    # Verifico che il nome fornito corrisponda ad un file GPX esistente
    if File.exists?(first_arg)
      file_name = first_arg

      # Temporaneo poi prenderlo da riga di comando
      nome_file_output = "risultato"

      dati = get_data(file_name, 200)
      
      dati = average_data(dati, 60)
      p dati.size
      
      # Disegno l'array filtrato, che rappresenta il grafico del guadagno orario (espresso in m/h)
      # di quota
      g.colors = ["red"]
      
      etichette = {}
      (0...20).each do |i|
        etichette[i*100] = "" #i.to_s
      end
      g.labels = etichette
      
      
      
      
      
      #g.data "m/h", dati
     
      #g.maximum_value = 800
      #g.minimum_value = -(dati.max / 2.0)
      
      #g.write("./#{nome_file_output}.png")
      
      
      g.data "m", get_elevations(dati)
      #g.data "bpm", get_cardio_frequencies(dati)
      
      g.line_width = 2
      g.write("./cardio.png")


      heart_rate_zones(dati)
      p ""
      cumulative_elevations(dati)

    else
        p "L'argomento specificato non è un file"
    end
end

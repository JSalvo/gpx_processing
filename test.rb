first_arg, *the_rest = ARGV

if first_arg.nil?
    p "Devi fornire il nome di un file gpx, come argomento"

else

    
    if File.exists?(first_arg)
    
    else
        p "L'argomento specificato non è un file"
    end
end





require './brains.rb'

class Player
  def initialize
    genome = File.open("./genome", "r"){|f| f.readlines}.join.split(",").map{|s| s.to_f} #Read genome from file.
    nodes = {:in => 16, :inner => 6, :out => 8} #3layernodes = {:in => 15, :inner => 8, :inner2 => 8, :out => 5} || #1layernodes = {:in => 15, :out => 5}
    @brain = Brains::R2D2.new(nodes, genome)  #Initialize warriors brain (neural net)
  end

  def play_turn(warrior)
    @previous_health ||= 20 
    inputs = input_array_for(warrior)       #Sense world and present as an array of inputs for NN   
    action, impulse = @brain.act_on(inputs) #send inputs to neural network and interpret its output as :action and :impulse
    puts [inputs, action, impulse].inspect  #whats on its mind?
  
    #send 'action' and impulse from brain to warrior.  done inside rescue as brain may request actions the body can't yet do, like rest! in the eariler levels.  
    #no need to program which actions are allowed, evolution will work it out for itself. Yes creationists, this shit actually works!  
    #Once evolved the brain will 'know' what its body is capable of and the rescue should not be needed. 
    begin 
      warrior.send(*["#{action}!", (action.eql?(:rest) ? nil : impulse)].compact)
    rescue NoMethodError => e
      puts "body failed to understand brain! #{e.message}"
    end
    @previous_health = warrior.health if warrior.respond_to?(:health)
  end

  #sense the world and return info as an array of inputs for the NN
  def input_array_for warrior
    dirs = [:left, :forward, :right, :backward] #directions in which things can be
    things = [:wall, :enemy, :captive]          #type of things there can be
    vis_scale = [0, 0.6, 0.3] #used to scale the values returned by :look.  

    if warrior.respond_to?(:feel)     
      can_look = warrior.respond_to?(:look)
      inputs = things.map do |thing|  #for each of the things
        dirs.map do |dir|             #in each of the directions
          v = (warrior.feel(dir).send("#{thing}?").eql?(true) ? 1 : 0) #test if that thing is there, returning 1 for true else 0
          if can_look                 #if warrior can also look
            look = warrior.look(dir)  #look in direction
            #reduce to a single val from given 3 ie [0,1,1] => [0, 0.6, 0.3] => [0.6]
            v = v + look.map{|l| (l.send("#{thing}?").eql?(true) ? 1 : 0) * vis_scale[look.index(l)] }.max
          end
          v
        end
      end
    else           
      #in the first level the warrior has less sensory input than a sea sponge.  No sensory input means no neural activity.
      #So when warrior does not respond to :feel it 'imagines' that its in an empty corridor!
      inputs = [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0] #inputs for empty corridor.
    end
    #give the NN sense of whether it is armed or not.
    inputs << (warrior.respond_to?(:shoot!) ? 1 : 0)

    #get health or return full health if health is not available.  Full health is 0 to dead at 1.  Resason is two fold;  The 'health' stimulus gets stronger
    #as the warrior gets weeker which should get the nerual nets attention and also to normalize it with other senses.
    w_health = warrior.respond_to?(:health) ? warrior.health : 20
    inputs << (1 - 1.0/20 * w_health).round(2) 
    inputs << ((@previous_health > w_health) ? 1 : 0) #sense of health dropping
    inputs << 1 #representational bias. yeah, I should prob explain this!  its REALLY important!  
    inputs.flatten #return array of values.
  end 
end

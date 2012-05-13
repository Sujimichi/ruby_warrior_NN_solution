require './brains.rb'

class Player
  def play_turn(warrior)
    @previous_health ||= 20 

    #Statemachine rubbish! - this is NOT AI!
    #return warrior.rest! if warrior.health < 18 && !warrior.feel.enemy?
    #return warrior.attack!(:forward) if warrior.feel.enemy?
    #return warrior.walk!(:forward)
    
    #nodes = {:in => 15, :inner => 8, :inner2 => 8, :out => 5}
    nodes = {:in => 15, :inner => 8, :out => 7}
    #nodes = {:in => 15, :out => 5}

    #Sense world and present as an array of inputs for NN
    inputs = input_array_for(warrior)

    #Read genome from file and divide into groups.  groups should be eql in size and the size should eql number of imputs to NN
    genome = File.open("./genome", "r"){|f| f.readlines}.join.split(",").map{|s| s.to_f}  
    brain = Brains::Type2.new(nodes, genome)  
    action, impulse = brain.act_on(inputs)
   
    puts inputs.inspect
    puts impulse.inspect
    puts action.inspect
   
    #The Body - send 'impulse' and 'action' from brain to the body

    #done inside rescue as brain may request actions the body can't yet do, like rest! in the eariler levels.  
    #no need to program which actions are allowed, evolution will work it out for itself. Yes creationists, this shit actually works!  
    #Once evolved the brain will 'know' what its body is capable of and the rescue should not be needed. 
    begin 
      unless impulse.eql?(:rest)
        warrior.send("#{action}!", impulse) 
      else
        warrior.rest!
      end
    rescue NoMethodError => e
      puts "body failed to understand brain! #{e.message}"
    rescue Exception => e
      puts "ERROR WENT DOWN #{e}"
    end

    @previous_health = warrior.health if warrior.respond_to?(:health)
   
  end


  def input_array_for warrior
    dirs = [:left, :forward, :right, :backward]
    things = [:wall, :enemy, :captive]#, :stairs, :ticking, :golem]

    a = []
    if warrior.respond_to?(:feel)
      things.each do |thing|
        dirs.each do |dir|
          begin
            a << (warrior.feel(dir).send("#{thing}?").eql?(true) ? 1 : 0)
          rescue
            a << 0
          end
        end
      end
    else     
      a = [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0] 
      #in the first level the warrior has less sensory input than a sea sponge.  No sensory input means no neural activity.
      #So when warrior does not respond to :feel it 'imagines' that its in an empty corridor!
    end

    #get health or return full health if health is not available.  Full health is 0 to dead at 1.  Resason is two fold;  The 'health' stimulus gets stronger
    #as the warrior gets weeker which should get the nerual nets attention and also to normalize it with other senses.
    begin
      w_health = warrior.health
    rescue
      w_health = 20
    end
    a << (1 - 1.0/20 * w_health).round(2)
    
    a << ((@previous_health > w_health) ? 1 : 0)
    a << 1 #representational bias. yeah, I should prob explain this!  its REALLY important!
    a
  end
  
end



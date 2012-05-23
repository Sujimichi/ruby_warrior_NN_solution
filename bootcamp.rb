require "./brains.rb"
require "./darwin.rb"

#BOOT CAMP - basic training
#subject neural nets to a pre-defined set of inputs and award points for correct actions
#Boot camp can be run very quickly for several thousand generations to get the population closer to required behavior
#After boot camp the population is transfered to run in the real conditions where the behaviours learnt in boot camp can be refined. 
#
#As well as faster runtimes Bootcamp also provides a smoother gradient for evolution.  In the "real environment" of rubywarior a great many positive 
#selection/mutation events need to happen before any points are awarded atall.  


#base class which BootCamp and CombatTraining inherit.  Simply provides methods for initializing a 1,2 or 3 layer NN(Brain), 
#saving and loading the population to file and running the GA.
class BasicTraining
  attr_accessor :ga, :nodes, :gene_length

  def set_config_for n_layers
    @warrior_name = Dir.getwd.split("/").last.sub("-beginner", "")
    @n_layers = n_layers
    nodes_1_layer = {:in => 16, :out => 8}
    nodes_2_layer = {:in => 16, :inner => 6, :out => 8}
    nodes_3_layer = {:in => 16, :inner => 6, :inner2 => 6, :out => 8}
    @nodes = [nodes_1_layer, nodes_2_layer, nodes_3_layer][@n_layers-1] 
    @gene_length = Brain.required_genome_length_for(nodes)
  end

  def train
    @ga.evolve
  end

  def write_best
    genome = @ga.best
    File.open("./genome",'w'){|f| f.write( genome.join(",") )}
  end

  def save_pop
    puts "enter a file name for population"
    f_name = gets.chomp #lvl4-twolayer-population
    return "no filename" if f_name.nil? || f_name.empty?
    pop_file = "./#{f_name}"
    File.open(pop_file,'w'){|f| f.write( @ga.population )}

  end
  def load_pop f_name
    require 'json'
    pop_file = "./#{f_name}"
    p = File.open(pop_file, "r"){|f| f.readlines}
    pop = JSON.parse p.first
    @ga.population = pop
  end

  def remark_on score
    if score > @highest_score 
      @highest_score = score
      print "\t\t<----BestSoFar"
    elsif score == @highest_score && score > 0
      print "\t\t<----Combat Ready!!"
    end
  end

  def reset_high_score
    @highest_score = -1000
  end
end

#BootCamp runs the evolution of a population of NNs over training examples from AssaultCourse.
class BootCamp < BasicTraining
  attr_accessor :recruit

  #n_layers - define which NN to use 1, 2 or 3 layered.
  def initialize n_layers = 2 
    set_config_for n_layers

    @ga = MGA.new(:generations => 100000, :mutation_rate => 10, :gene_length => @gene_length, :popsize => 80, :fitness => Proc.new{|genome, gen|
      print "#{gen} |"

      @recruit = Brains[@n_layers-1].new(@nodes, genome)  #initialize brain(neural net) with current genome.
      d = DrillSergeant.new   #initialize a DrillSergeant, a class used to score the brain response to a set of predefined inputs in AssaultCourse
      d.recruit = @recruit     #set the brain to be evaulated     

      #Basic walking drills - move in only available dir
      d.test_recruit_on(AssaultCourse::BasicManuvers)       #learn to walk
      d.test_recruit_on(AssaultCourse::Retreat)
      d.test_recruit_on(AssaultCourse::BasicAssault)      #learn to attack in adjacent sqaures

      unless d.score.include?(0)
        d.test_recruit_on(AssaultCourse::Recovery )         #learn to recover when damaged
        d.test_recruit_on(AssaultCourse::CloseQuaterCombat) #learn to attack enemy in closed spaces
        d.test_recruit_on(AssaultCourse::AdvancedCombat)    #learn to shoot and move toward distant targets
        d.test_recruit_on(AssaultCourse::Rescue)            #basic rescue - rescue captive in adjacent sqaures
      end
      message = "\t\t - Graduated BootCamp!" unless d.score.include?(0) #40
      score = d.score.sum.to_i
      #AssaultCourse.points.values.sum
      print "\t\t- #{score}"
      print message if message
      puts " "
      score
    }) 
  end

  def graduate
    ct = CombatTraining.new(@n_layers)
    ct.ga.population = @ga.population
    ct
  end

end

#CombatTraining runs the evolution of a population of NNs in the current level of rubywarrior.
class CombatTraining < BasicTraining

  def initialize n_layers
    set_config_for n_layers
    reset_high_score

    @ga =MGA.new(:generations => 5000, :mutation_rate => 2, :gene_length => @gene_length, :fitness => Proc.new{|genome, gen|
      print "#{gen}"
      File.open("./genome", 'w'){|f| f.write( genome.join(",") )} #write the genome to file which Player will use
      invigilator = Invigilator.new(@warrior_name)  #invigilator class examins output from rubywarrior and assigns points for various actions.  Invigilator#score_results == the fitness function
      results = `rubywarrior -t 0 -s` #run runywarrior

      #use invigilator to get the final score.  Also returns the break down of points for displaying.
      score, level_score, level_total, n_turns, turn_score, time_bonus, clear_bonus = invigilator.score_results(results)
      print " | levelscore: #{level_score} | turnscore: #{turn_score.round(2)} | bonus(t:c): #{time_bonus}:#{clear_bonus} | turns: #{n_turns} | Total: #{level_total} | fitnes: #{score.round(2)}"

      remark_on score
      puts "."
      score
    })

  end

end

#AgentTrainingruns the evolution of a population of NNs over all the levels of rubywarrior in epic mode.
#Only available once passed epic mode.  
class AgentTraining < BasicTraining
  def initialize n_layers
    set_config_for n_layers
    reset_high_score

    @ga =MGA.new(:generations => 5000, :mutation_rate => 2, :gene_length => @gene_length, :fitness => Proc.new{|genome, gen|
      puts "#{gen}\n"

      genome_file = "./genome"
      File.open(genome_file,'w'){|f| f.write( genome.join(",") )}
      invigilator = Invigilator.new(@warrior_name)
      score_sum = 0
      threads = []
      levels = [1,2,3,4,5,6,7,8,9]
      levels.each do |i|
        threads << Thread.new{
          results = `rubywarrior -t 0 -s -l #{i}`
          score, level_score, level_total, n_turns, turn_score, time_bonus, clear_bonus = invigilator.score_results results
          puts "Level#{i} | levelscore: #{level_score} | turnscore: #{turn_score.round(2)} | bonus(t:c): #{time_bonus}:#{clear_bonus} | turns: #{n_turns} | Total: #{level_total} | fitnes: #{score.round(2)}"
          instance_variable_set("@ans#{i}", score)
        }
      end
      threads.each{|t| t.join}
      score_sum = levels.map{|i| instance_variable_get("@ans#{i}")}.compact.sum
      puts "\n\t==Summed Score #{score_sum}"
      remark_on score_sum
      #puts genome.join(",")
      puts "."
      score_sum
    })
  end
end

#FieldTraining runs the evolution of a population of NNs in each level of rubywarrior (non-epic)
#Requires some setup.  Needs a rubywarrior dir setup for each level named levelxbot where x is the level number.
class FieldTraining < BasicTraining

  def initialize n_layers
    set_config_for n_layers
    reset_high_score

    #levels = [1,2,3,4,5,6,7,8,9]
    levels = [1,2,3,4,5,6,7]

    rootdir = "/home/sujimichi/coding/lab/rubywarrior"

    @ga =MGA.new(:generations => 5000, :mutation_rate => 2, :gene_length => @gene_length, :fitness => Proc.new{|genome, gen|
      puts "#{gen}\n"
      Dir.chdir(rootdir)
    
      threads = []
      levels.each do |lvl|
        Dir.chdir("#{rootdir}/level#{lvl}bot-beginner")
        File.open("./genome", 'w'){|f| f.write( genome.join(",") )} #write the genome to file which Player will use
        

        threads << Thread.new {         
          invigilator = Invigilator.new(@warrior_name)  #invigilator class examins output from rubywarrior and assigns points for various actions.  Invigilator#score_results == the fitness function
          #puts "in dir #{Dir.getwd}"
          results = `rubywarrior -t 0 -s` #run runywarrior
          #use invigilator to get the final score.  Also returns the break down of points for displaying.
          score, level_score, level_total, n_turns, turn_score, time_bonus, clear_bonus = invigilator.score_results(results)
          puts "level-#{lvl}|levelscore: #{level_score} | turnscore: #{turn_score.round(2)} | bonus(t:c): #{time_bonus}:#{clear_bonus} | turns: #{n_turns} | Total: #{level_total} | fitnes: #{score.round(2)}"
          instance_variable_set("@ans#{lvl}", score)
        }
        sleep(0.5)
  
      end
      threads.each{|t| t.join}

      score_sum = levels.map{|lvl| instance_variable_get("@ans#{lvl}")}.compact.sum
       
      puts "| Summed Score #{score_sum}"
      remark_on score_sum
      puts "."
      score_sum

    })

  end


end



#AssaultCourse defines a set of predefined inputs and thier expected output grouped into a number of constants. 
class AssaultCourse
  #input mapping; 
  #   < /\ > \/ => left, forward, right, backward
  #   Hc, Hp, Ar => Health_current, Health_previous and Armed?
  #   r => representational bias
  #
  # [w<, w/\, w>, w\/, e<, e/\, e>, e\/, c<, c/\, c>, c\/, Ar, Hc, Hp, r]
  # [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0, 1]

  def self.points
    AssaultCourse.constants.map{|c| {c => AssaultCourse.const_get(c).size}}.inject{|i,j| i.merge(j)}
  end

  r = 1 #representational bias

  BasicManuvers = {
    #[0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :left],
    [1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :forward],
    #[1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :right],
    [1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :backward],

    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :forward, '0wf'], #Dont just sit there, do something.
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :forward, 'fwc']
  }

  Retreat = {
    [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0.9, 1, r] => [:walk, :backward, 'RetR1'],  #walls either side T infront, health low -> retreat
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.9, 1, r] => [:walk, :backward, 'RetR2'],   #walls either side T infront, health low, being shot at -> retreat
  }

  #Basic Attack - attack enemy in adjacent squares when in open space
  BasicAssault = {
    #[0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :left],         
    [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :forward],
    #[0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :right],
    [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :backward],
    [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:attack, :forward, 'af2'],  #attack forward with walls either side
    [1, 0, 1, 0, 0, 0.6, 0, 0, 0, 0, 0, 0, 1, 0.0, 0, r] => [:shoot, :forward, 'SF1']
  }

  #learn to recover after fight
  Recovery = {
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.90, 0, r] => [:rest, :rest, 'R9'],  #recover from 90% damage
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.80, 0, r] => [:rest, :rest, 'R8'],  #recover from 80% damage  
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.70, 0, r] => [:rest, :rest, 'R7'],  #recover from 70% damage  
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.60, 0, r] => [:rest, :rest, 'R6'],  #recover from 50% damage        
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.50, 0, r] => [:rest, :rest, 'R5'],  #recover from 50% damage  
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.40, 0, r] => [:rest, :rest, 'R4'],  #recover from 40% damage  

    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.65, 1, r] => [:walk, :forward, 'WFD0'], #limp on if only slightly hurt and under fire (specific example from level 4)
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.40, 1, r] => [:walk, :forward, 'WFD1'], #limp on if only slightly hurt and under fire
    [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.20, 1, r] => [:walk, :forward, 'WFD2'],  #limp on if only slightly hurt and under fire
   
  }
  
  CloseQuaterCombat =  {
    [1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0.0, 0, r] => [:pivot,  :backward, 'PV'],  #watch your back maggot!
    [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0.0, 0, r] => [:attack, :forward, 'AF1'],  #walls either side T infront
    [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0.1, 1, r] => [:attack, :forward, 'AF2'],  #walls either side T infront attacking          
    [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0.3, 1, r] => [:attack, :forward, 'AF3'],  #walls either side T infront attacking
    [1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0.5, 1, r] => [:attack, :forward, 'AF4'],  #walls either side T infront attacking
  } 

  AdvancedCombat = {
    [1, 0, 1, 0, 0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0, r] => [:walk, :forward, 'mv0'],  #walk toward distant target    
    [1, 0, 1, 0, 0, 0.3, 0, 0, 0, 0, 0, 0, 0, 0.0, 0, r] => [:walk, :forward, 'mv1'],  #walk toward distant target
    [1, 0, 1, 0, 0, 0.6, 0, 0, 0, 0, 0, 0, 0, 0.0, 0, r] => [:walk, :forward, 'mv2'],  #walk toward distant target
    [1, 0, 1, 0, 0, 1.0, 0, 0, 0, 0, 0, 0, 0, 0.0, 0, r] => [:attack, :forward, 'AF0'],  #attack forward with vision but no gun
    
    [1, 0, 1, 0, 0, 0.6, 0, 0, 0, 0, 0, 0, 1, 0.0, 0, r] => [:shoot, :forward, 'SF1'],  #walls either side high_threat target in distance infront        
    [1, 0, 1, 0, 0, 0.6, 0, 0, 0, 0, 0, 0, 1, 0.2, 1, r] => [:shoot, :forward, 'SF2'],  #walls either side high_threat target in distance infront        
    [1, 0, 1, 0, 0, 0.6, 0, 0, 0, 0, 0, 0, 1, 0.4, 1, r] => [:shoot, :forward, 'SF3'],  #walls either side high_threat target in distance infront        

    #[1, 0, 1, 0, 0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0.0, 0, r] => [:walk, :backward, 'AIM1'],
    #[1, 0, 1, 0, 0, 1.0, 0, 0, 0, 0, 0, 0, 1, 0.2, 1, r] => [:walk, :backward, 'AIM2']    
  }

  Rescue =  {
    #[0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, r] => [:rescue, :left],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, r] => [:rescue, :forward],
    #[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, r] => [:rescue, :right],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, r] => [:rescue, :backward],          
  }      
end

#Invigilator is used to inspect the results from a run of rubywarrior and calculate a score.
#It is essentially the fitness function for the GAs.
class Invigilator

  def initialize name = Dir.getwd.split("/").last.sub("-beginner", "")
    @warrior_name = Dir.getwd.split("/").last.sub("-beginner", "")
  end

  def score_results results
    
    lines = results.split("\n") 
    turns = results.split("- turn")

    begin
      level_total = lines.select{|line| line.include?("Total Score:")}.first.split("=").last.to_i
      time_bonus = lines.select{|line| line.include?("Time Bonus:")}.first.split(" ").last.to_i if results.include?("Time Bonus:")
      clear_bonus = lines.select{|line| line.include?("Clear Bonus:")}.first.split(" ").last.to_i if results.include?("Clear Bonus:")
    rescue
      level_total = -200 #punishment for failing to complete level
    end

    time_bonus ||= 0
    clear_bonus ||= 0
    #level score based of points awarded during game.  
    level_score = lines.select{|line| line.include?("earns")}.map{|l| l.split[2].to_i}.inject{|i,j| i+j}
    level_score ||= -100 #punishment for not earning anything


    turn_score = []
    turns.each do |turn|

      turn_score << 15 if turn.match(/#{@warrior_name} receives (\d) health/) && !( turn.match(/#{@warrior_name} takes (\d) damage/) || turn.match(/already fit as a fiddle/) )
      turn_score << -20 if turn.match(/already fit as a fiddle/) #equates to doing nothing.

      %w[forward backward left right].each do |dir|
        turn_score <<  3  if turn.match(/#{@warrior_name} attacks #{dir} and hits/) && !(turn.match(/#{@warrior_name} attacks #{dir} and hits nothing/) || turn.match(/hits Captive/))
        turn_score << -6  if turn.match(/#{@warrior_name} attacks #{dir} and hits/) &&  (turn.match(/#{@warrior_name} attacks #{dir} and hits nothing/) || turn.match(/hits Captive/))
        turn_score <<  4  if turn.match(/#{@warrior_name} shoots #{dir} and hits/)  && !(turn.match(/#{@warrior_name} shoots #{dir} and hits nothing/) || turn.match(/hits Captive/))
        turn_score << -8  if turn.match(/#{@warrior_name} shoots #{dir} and hits/)  &&  (turn.match(/#{@warrior_name} shoots #{dir} and hits nothing/) || turn.match(/hits Captive/))
        turn_score <<  50 if turn.match(/#{@warrior_name} unbinds #{dir} and rescues Captive/)         
      end

      #will already have points for forward attack, this is a bonus for successful forward attack
      turn_score <<  1  if turn.match(/#{@warrior_name} attacks forward and hits/) && !(turn.match(/#{@warrior_name} attacks forward and hits nothing/) || turn.match(/hits Captive/))


      turn_score << -6  if turn.match(/Captive dies/)
      turn_score << -4 if turn.match(/#{@warrior_name} does nothing/)
      turn_score << -4 if turn.match(/#{@warrior_name} walks/) && turn.match(/#{@warrior_name} bumps/)
      turn_score <<  2 if turn.match(/#{@warrior_name} walks forward/) && !turn.match(/#{@warrior_name} bumps/)

    end

    turn_score = turn_score.sum
    n_turns = turns.size-1
    turn_score = (turn_score.to_f/n_turns)*4


    bonus = clear_bonus*3 + time_bonus*3 #times three to increase onerous to earn bonuses.


    score = level_score + level_total + bonus + (turn_score/n_turns.to_f)
    return [score, level_score, level_total, n_turns, turn_score, time_bonus, clear_bonus]
  end

end




#DrillSergeant provides a way of testing a NN's response to a given input.  It has a method 'test_recruit_on' which takes a hash which defines {input_array => response_array}
#response_array must include [action, impulse] but can also include an alternative 'code' and different point value ie[:walk, :forward, 'wfd', 2]
#Several examples can be passed in one test.  .score will return the current score which is an array of accumulated points
#
# d = DrillSergeant.new
# d.recruit = recruit #recruit is a 'brain' from Brains
# d.test( { 
#   [1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :forward],
#   [1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, r] => [:walk, :backward]
# )} 
class DrillSergeant
  attr_accessor :score, :recruit
  def initialize 
    @score = []
  end

  def test_recruit_on args
    args.each do |input,response| 
      code = response[2] || response.map{|s| s.to_s.each_char.map.first}.join #code is str which is output if the input == response
      points = response[3] || 1 #number of points awarded for input == response, default 1
      @score << (@recruit.act_on(input).eql?(response[0..1]) ? (print(code);points) : 0)
    end
  end
end


class CrossBreeder
  attr_accessor :genomes

  def read_genomes
    d = Dir.getwd
    Dir.chdir("genomes by level")
    files = Dir.open(".").to_a.select{|f| f.include?("genome")}

    @genomes = files.map do |file|
      File.open(file, "r"){|f| f.readlines}.join.split(",").map{|s| s.to_f}
    end
    Dir.chdir(d)
  end

  def make_pop size = 80
    read_genomes unless @genomes
    n = size/@genomes.size
    pop = []
    n.times{ @genomes.each{|genome| pop << genome} }
    pop
  end

end

require "./brains.rb"
require "./darwin.rb"

#This file contains a collection of classes which are used in the evolution of the neural networks.  Nothing in here is needed to run a trained NN in rubywarrior.
#There are several classes which are used to run evolution on 'populations' in a number of ways.
#
#BootCamp - used to evolve a population of NN's to respond to a set of predefined inputs and outputs 
#The predefined inputs/outputs are from AssaultCourse and DrillSergeant observes a NN's performance over the AssaultCourse
#
#CombatTraining - used to evolve NN's in a rubywarrior level
#The performance of the NN in the rubywarrior level is determined by Invigilator
#
#AgentTraining - used to evolve NN's over all levels in rubywarrior EPIC mode.
#requires epic unlocked.
#
#FieldTraining - used to evolve NN's over several/all rubywarrior levels.
#requires some setup and levels to be unlocked; A specific rubywarrior folder needs to be created for each level according to a naming convention see FieldTraining for more.
#
#Agent and Field use Threads to evaluate a NN's performance in all levels together, thier output gets a bit nutts at times ;)
#
#All four training grounds inherit from BasicTraining 
#Provides some common methods for runnning evolution, saving/loading/autosaving populations to file and some getting/setter methods for the GA (population,muation_rate)
#
#Each of the four 'training grounds' set the args for a genetic alg and define the 'fitness function'.  All follow the same basic format and only define an initialize method, ie;
#
# class BootCamp < BasicTraining
#   def initialize n_layers
#     #init vars
#     @ga = MGA.new(:generations => 1000, :mutation_rate => 10, :gene_length => @gene_length, :fitness => Proc.new{|genome, gen|
#       nn = Brains[n_layers-1].new(@nodes, genome)
#       #code to test nn's performance and return its score 
#     })
#   end
# end
#
#Training grounds take a single integer arg in thier initialize method which defines how many layers (n_layers) the NN should have; 1, 2 or 3.
#The :set_config_for method in BasicTraining defines how many nodes to used in each layer as sets @nodes.
#
#Brains (from brains.rb) simply indexes the three types of NN, 1, 2 and 3 layer, ie; Brians[0] returns a 1 layer NN Brain.  see brains.rb for more.
#
#Usage
#
#bc = BootCamp.new(2)
#bc.train
#bc.save_pop "popname"
#bc.write_best #find best genome and save to genome file
#

#BOOT CAMP - basic training
#subject neural nets to a pre-defined set of inputs and award points for correct actions
#Boot camp can be run very quickly for several thousand generations to get the population closer to required behavior
#After boot camp the population is transfered to run in the real conditions where the behaviours learnt in boot camp can be refined. 
#
#As well as faster runtimes Bootcamp also provides a smoother gradient for evolution.  In the "real environment" of rubywarior a great many positive 
#selection/mutation events need to happen before any points are awarded atall.  


#base class which all training grounds inherit.
class BasicTraining
  attr_accessor :ga, :nodes, :gene_length

  def set_config_for n_layers = 2
    raise "Look, just no!" unless [1,2,3].include?(n_layers)
    @warrior_name = Dir.getwd.split("/").last.sub("-beginner", "")
    @n_layers = n_layers   
    nodes_1_layer = {:in => 16, :out => 8}
    nodes_2_layer = {:in => 16, :inner => 6, :out => 8}
    nodes_3_layer = {:in => 16, :inner => 6, :inner2 => 6, :out => 8}
    @nodes = [nodes_1_layer, nodes_2_layer, nodes_3_layer][@n_layers-1] 
    @gene_length = Brain.required_genome_length_for(nodes)
  end

  #calls evolve on the Genetic Algorithm in @ga.  also provides functionality for auto saving the population during evolution.
  def train use_new_name = false
    if @auto_save_every_n_generations #can be set to an int to have the population written to file even n generations.  
      n = @auto_save_every_n_generations
      i = @ga.generations/n
      #workout what name to use to auto save population as.  If use_name_name is true a new name will be used for that call to :train.  
      # ie 
      # bootcamp.train #=> first time sets a new name based on inital state
      # bootcamp.train #=> stop execution and then run again, will use same name as before
      # bootcamp.train true #=> will use a new name based on current state
      # bootcamp.train "custom_name" #=> will use the given name.
      if use_new_name && !use_new_name.eql?(true) #not false, but not true; a string perhaps
        @uniq_name = use_new_name 
        use_new_name = false
      end
      use_new_name = true unless @uniq_name
      if use_new_name
        require 'digest'
        d = Digest::MD5.new
        d << @ga.instance_variables.map{|v| @ga.instance_variable_get(v) }.compact.join      
        @uniq_name = d.hexdigest 
      end
      name = "current_pop_#{@nodes.size-1}layer-#{@nodes.values.join("-")}_#{self.class.to_s}_#{@uniq_name}"     

      i.times do |i|
        @ga.evolve(n)
        print "\n\nran #{n} generations.  Saving population as #{name}...."
        self.save_pop name
        puts "done.\n\n"
      end
    else
      @ga.evolve
    end  
  end
  alias run train

  def write_best
    genome = @ga.best
    File.open("./genome",'w'){|f| f.write( genome.join(",") )}
  end

  def population
    @ga.population
  end
  def population= new_population
    @ga.population = new_population
  end

  def save_pop name = nil
    PopBuilder.save_pop(@ga.population, name)
  end
  def load_pop f_name
    pop = PopBuilder.load_pop(f_name)
    @ga.population = pop
  end

  def build_pop_from pop_size = 30, genome_dir = "genomes by level"
    builder = PopBuilder.new
    builder.read_genomes genome_dir
    pop = builder.make_pop(pop_size)
    @ga.population = pop
    @ga.popsize = pop.size
    @ga
  end
  alias build_pop build_pop_from

  def mutation_rate mutation_rate = nil
    orig_m = @ga.mutation_rate
    return orig_m if mutation_rate.nil?
    @ga.mutation_rate = mutation_rate
    puts "mutation rate changed; #{orig_m} => #{mutation_rate}"
  end

  def remark_on score
    @target_score ||= 0
    if score > @highest_score 
      @highest_score = score
      print "\t\t<----BestSoFar"
    elsif score == @highest_score && score >= @target_score
      print "\t\t<----Combat Ready!!"
    end
  end

  def reset_high_score
    @highest_score = -10000
  end

  def graduate
    training_grounds = [BootCamp, CombatTraining, AgentTraining, FieldTraining]
    cur_pos = training_grounds.index(self.class)
    return "No more training grounds, run write_best and go kick RW's ass!" if cur_pos >= training_grounds.size-1
    new_training_groud = training_grounds[cur_pos.next].new(@n_layers)
    new_training_groud.population = self.population.clone
    new_training_groud
  end

  
end

#BootCamp runs the evolution of a population of NNs over training examples from AssaultCourse.
class BootCamp < BasicTraining
  attr_accessor :recruit

  #n_layers - define which NN to use 1, 2 or 3 layered.
  def initialize n_layers = 2 
    @auto_save_every_n_generations = 1000
    set_config_for n_layers

    @ga = MGA.new(:generations => 100000, :mutation_rate => 10, :gene_length => @gene_length, :popsize => 30, :fitness => Proc.new{|genome, gen|
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


end

#CombatTraining runs the evolution of a population of NNs in the current level of rubywarrior.
class CombatTraining < BasicTraining

  def initialize n_layers = 2
    @auto_save_every_n_generations = 500
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
  def initialize n_layers = 2
    @auto_save_every_n_generations = 100
    @target_score = 842
    set_config_for n_layers
    reset_high_score

    @ga =MGA.new(:generations => 5000, :mutation_rate => 2, :gene_length => @gene_length, :fitness => Proc.new{|genome, gen|
      puts "#{gen}\n"

      genome_file = "./genome"
      File.open(genome_file,'w'){|f| f.write( genome.join(",") )}
      
      score_sum = 0
      threads = []
      levels = [1,2,3,4,5,6,7,8,9]
      levels.each do |i|
        threads << Thread.new{
          results = `rubywarrior -t 0 -s -l #{i}`
          invigilator = Invigilator.new
          score, level_score, level_total, n_turns, turn_score, time_bonus, clear_bonus = invigilator.score_results results
          puts "Level#{i} | levelscore: #{level_score} | turnscore: #{turn_score.round(2)} | bonus(t:c): #{time_bonus}:#{clear_bonus} | turns: #{n_turns} | Total: #{level_total} | fitnes: #{score.round(2)}"
          instance_variable_set("@ans#{i}", score)
        }
      end
      threads.each{|t| t.join}
      score_sum = levels.map{|i| instance_variable_get("@ans#{i}")}.compact.sum
      puts "\n\t==Summed Score #{score_sum}"
      remark_on score_sum
      puts "."
      score_sum
    })
  end
end


#FieldTraining runs the evolution of a population of NNs in each level of rubywarrior (non-epic)
#Requires some setup.  Needs a rubywarrior dir setup for each level named levelxbot where x is the level number.
class FieldTraining < BasicTraining

  def initialize n_layers =2
    @auto_save_every_n_generations = 100
    @target_score = 842
    set_config_for n_layers   
    reset_high_score

    @initial_dir = Dir.getwd
    levels = [1,2,3,4,5,6,7,8,9]

    rootdir = "/home/sujimichi/coding/lab/rubywarrior"

    @ga =MGA.new(:generations => 5000, :mutation_rate => 2, :gene_length => @gene_length, :fitness => Proc.new{|genome, gen|
      puts "#{gen}\n"
      Dir.chdir(rootdir)

      level_factor = [0.8, 1.0, 0.8, 0.6, 0.4, 0.9, 1.0, 1.0, 1.0]

      puts "\n\n"
    
      threads = []
      levels.sort_by{rand}.each do |lvl|
        Dir.chdir("#{rootdir}/level#{lvl}bot-beginner")
        File.open("./genome", 'w'){|f| f.write( genome.join(",") )} #write the genome to file which Player will use
        

        threads << Thread.new {         
          invigilator = Invigilator.new #invigilator class examins output from rubywarrior and assigns points for various actions.  Invigilator#score_results == the fitness function
          results = `rubywarrior -t 0 -s` #run runywarrior
          #use invigilator to get the final score.  Also returns the break down of points for displaying.
          score, level_score, level_total, n_turns, turn_score, time_bonus, clear_bonus = invigilator.score_results(results)   

          score = score * level_factor[lvl-1]


          puts "level-#{lvl}|levelscore: #{level_score} | turnscore: #{turn_score.round(2)} | bonus(t:c): #{time_bonus}:#{clear_bonus} | turns: #{n_turns} | Total: #{level_total} | fitnes: #{score.round(2)}"
          instance_variable_set("@ans#{lvl}", score) #set result in an @var ie @ans1.  Done so threads don't try to write answer to a common var.
          Dir.chdir(@initial_dir)
        }
        sleep(0.3) #This sleep is a horrible hack arround the problem of current directory not being thread safe.
        #For each level it first changes into the levels directory and then runs rubywarrior in a new Thread.  Then sleeps.  
        #After the sleep it moves the the next level and moves to its dir and again runs rubywarrior in a new Thread.  
        #Without the sleep all the threads would be started almost at the same time and would start in which ever directory was now the current directory.
        #This could cause the first level's rubywarrior command to be called in the next levels dir.
  
      end
      threads.each{|t| t.join}

      score_sum = levels.map{|lvl| instance_variable_get("@ans#{lvl}")}.compact.sum #collect up and sum the defined @vars with the results.
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

      #will already have points for forward attack, this is a bonus for successful *forward* attack
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




#DrillSergeant provides a way of testing a NN's response to a given input.  The method 'test_recruit_on' takes a hash which defines {input_array => response_array}
#response_array must include [action, impulse] but can also include an alternative 'code' and different point value ie[:walk, :forward, 'wfd', 2]
#Several examples can be passed in one test.  1.score will return the current score which is an array of accumulated points
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



class PopBuilder
  attr_accessor :genomes

  def read_genomes genome_dir = "genomes by level"
    d = Dir.getwd
    Dir.chdir(genome_dir)
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

  def get_best pop, ga, best_n = 10
    pop.sort_by{|m| ga.fitness(m)}.reverse[0..best_n] 
  end

  def combine_best_from pops, ga, end_size = nil
    @genomes = pops.map{|pop| get_best(pop,ga) }.flatten
    end_size = @genomes.size * 2 if end_size.nil?
    make_pop(end_size)    
  end

  def self.load_pop f_name
    require 'json'
    pop_file = "./#{f_name}"
    pop = File.open(pop_file, "r"){|f| f.readlines}
    JSON.parse pop.first
  end

  def self.save_pop population, f_name = nil
    unless f_name
      puts "enter a file name for population"
      f_name = gets.chomp 
    end
    return "no filename" if f_name.nil? || f_name.empty?
    pop_file = "./#{f_name}"
    File.open(pop_file,'w'){|f| f.write( population )}   
  end

end


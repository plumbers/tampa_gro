class AddHistogramQuestions < ActiveRecord::Migration
  def up

    create_table :scorecard_histogram_questions do |t|
      t.integer :ids,  default: [], null: false, array: true
      t.string  :question
    end

    add_index :scorecard_histogram_questions, :ids, name: :scorecard_histogram_questions_ids_idx, using: :gin
    add_index :scorecard_histogram_questions, :question, name: :scorecard_histogram_questions_question_idx
    add_index :scorecard_histogram_questions, :question, name: :scorecard_histogram_questions_question_hash_idx, using: :hash
  end


  def down
    drop_table :scorecard_histogram_questions
  end

end
